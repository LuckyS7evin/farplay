// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#include "farplay/fsrframegen.h"

#include <ffx_api.h>
#include <ffx_api_types.h>
#include <vk/ffx_api_vk.h>
#include <ffx_framegeneration.h>

#include <QCoreApplication>
#include <QDir>
#include <QMutex>
#include <QMutexLocker>
#include <QtGlobal>

#include <algorithm>
#include <cstring>

#ifdef Q_OS_WIN
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

namespace farplay {

namespace {

// Messages du runtime AMD (thread quelconque) : conservés pour l'overlay.
QMutex g_msg_mutex;
QString g_last_msg;

void ffxMessage(uint32_t type, const wchar_t *message)
{
    const QString m = QString::fromWCharArray(message ? message : L"");
    qWarning("Farplay FSR %s: %s", type == FFX_API_MESSAGE_TYPE_ERROR ? "erreur" : "avertissement",
             qPrintable(m));
    if (type == FFX_API_MESSAGE_TYPE_ERROR) {
        QMutexLocker l(&g_msg_mutex);
        g_last_msg = m.left(160);
    }
}

QString lastMessage()
{
    QMutexLocker l(&g_msg_mutex);
    return g_last_msg;
}

} // namespace

struct FsrFrameGen::Vk {
    PFN_vkGetDeviceProcAddr GetDeviceProcAddr = nullptr;
    PFN_vkGetDeviceQueue GetDeviceQueue = nullptr;
    PFN_vkCreateCommandPool CreateCommandPool = nullptr;
    PFN_vkDestroyCommandPool DestroyCommandPool = nullptr;
    PFN_vkAllocateCommandBuffers AllocateCommandBuffers = nullptr;
    PFN_vkBeginCommandBuffer BeginCommandBuffer = nullptr;
    PFN_vkEndCommandBuffer EndCommandBuffer = nullptr;
    PFN_vkResetCommandBuffer ResetCommandBuffer = nullptr;
    PFN_vkQueueSubmit QueueSubmit = nullptr;
    PFN_vkWaitSemaphores WaitSemaphores = nullptr;
    PFN_vkDeviceWaitIdle DeviceWaitIdle = nullptr;
};

FsrFrameGen::~FsrFrameGen()
{
    destroy();
}

void FsrFrameGen::fail(const QString &why)
{
    failed_ = true;
    error_ = why;
    qWarning("Farplay FSR: %s", qPrintable(why));
}

QString FsrFrameGen::status() const
{
    if (failed_)
        return QStringLiteral("erreur : ") + error_;
    if (!usable_)
        return error_.isEmpty() ? QStringLiteral("indisponible") : QStringLiteral("indisponible : ") + error_;
    if (provider_.isEmpty())
        return QStringLiteral("prêt");
    return QStringLiteral("FSR ") + provider_ + (provider_.startsWith(QLatin1String("4.")) ? QStringLiteral(" (IA)") : QString());
}

bool FsrFrameGen::loadLibrary()
{
#ifdef Q_OS_WIN
    if (module_)
        return true;
    const QString dir = QDir::toNativeSeparators(QCoreApplication::applicationDirPath());
    // Le chargeur cherche les fournisseurs (amd_fidelityfx_framegeneration_vk.dll)
    // dans le dossier de chargement : on l'ajoute explicitement.
    SetDllDirectoryW(reinterpret_cast<LPCWSTR>(dir.utf16()));
    const QString path = dir + QStringLiteral("\\amd_fidelityfx_loader_vk.dll");
    HMODULE m = LoadLibraryW(reinterpret_cast<LPCWSTR>(path.utf16()));
    SetDllDirectoryW(nullptr);
    if (!m) {
        error_ = QStringLiteral("amd_fidelityfx_loader_vk.dll absente");
        return false;
    }
    const char *names[5] = { "ffxCreateContext", "ffxDestroyContext", "ffxConfigure", "ffxQuery", "ffxDispatch" };
    for (int i = 0; i < 5; i++) {
        fns_[i] = reinterpret_cast<void *>(GetProcAddress(m, names[i]));
        if (!fns_[i]) {
            error_ = QStringLiteral("fonction %1 absente du chargeur AMD").arg(QLatin1String(names[i]));
            FreeLibrary(m);
            return false;
        }
    }
    module_ = m;
    return true;
#else
    error_ = QStringLiteral("Windows uniquement");
    return false;
#endif
}

void FsrFrameGen::init(pl_vulkan vk, pl_log log)
{
    destroy();
    failed_ = false;
    error_.clear();
    provider_.clear();
    log_ = log;
    if (!vk) {
        error_ = QStringLiteral("rendu Vulkan requis");
        return;
    }
    vk_ = vk;
    gpu_ = vk->gpu;
    if (!loadLibrary())
        return;

    vkf_ = new Vk();
    auto gipa = vk->get_proc_addr;
    vkf_->GetDeviceProcAddr = reinterpret_cast<PFN_vkGetDeviceProcAddr>(gipa(vk->instance, "vkGetDeviceProcAddr"));
    if (!vkf_->GetDeviceProcAddr) {
        error_ = QStringLiteral("vkGetDeviceProcAddr introuvable");
        return;
    }
#define FP_LOAD(name) vkf_->name = reinterpret_cast<PFN_vk##name>(vkf_->GetDeviceProcAddr(vk->device, "vk" #name)); \
    if (!vkf_->name) { error_ = QStringLiteral("vk" #name " introuvable"); return; }
    FP_LOAD(GetDeviceQueue)
    FP_LOAD(CreateCommandPool)
    FP_LOAD(DestroyCommandPool)
    FP_LOAD(AllocateCommandBuffers)
    FP_LOAD(BeginCommandBuffer)
    FP_LOAD(EndCommandBuffer)
    FP_LOAD(ResetCommandBuffer)
    FP_LOAD(QueueSubmit)
    FP_LOAD(WaitSemaphores)
    FP_LOAD(DeviceWaitIdle)
#undef FP_LOAD

    qf_ = vk->queue_graphics.index;
    qidx_ = 0;
    vkf_->GetDeviceQueue(vk->device, qf_, qidx_, &queue_);

    VkCommandPoolCreateInfo pci = {};
    pci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    pci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    pci.queueFamilyIndex = qf_;
    if (vkf_->CreateCommandPool(vk->device, &pci, nullptr, &pool_) != VK_SUCCESS) {
        error_ = QStringLiteral("création du command pool impossible");
        return;
    }
    VkCommandBufferAllocateInfo ai = {};
    ai.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    ai.commandPool = pool_;
    ai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    ai.commandBufferCount = kCmd;
    if (vkf_->AllocateCommandBuffers(vk->device, &ai, cmd_) != VK_SUCCESS) {
        error_ = QStringLiteral("allocation des command buffers impossible");
        return;
    }
    struct pl_vulkan_sem_params sp = {};
    sp.type = VK_SEMAPHORE_TYPE_TIMELINE;
    sp.initial_value = 0;
    sem_ = pl_vulkan_sem_create(gpu_, &sp);
    if (!sem_) {
        error_ = QStringLiteral("sémaphore timeline indisponible");
        return;
    }
    usable_ = true;
}

void FsrFrameGen::destroyContext()
{
    if (ctx_ && fns_[1]) {
        if (vkf_ && vk_)
            vkf_->DeviceWaitIdle(vk_->device);
        ffxContext c = ctx_;
        reinterpret_cast<PfnFfxDestroyContext>(fns_[1])(&c, nullptr);
    }
    ctx_ = nullptr;
    ctx_w_ = ctx_h_ = 0;
    ctx_fmt_ = nullptr;
    frame_id_ = 0;
}

void FsrFrameGen::destroy()
{
    destroyContext();
    if (gpu_) {
        pl_tex_destroy(gpu_, &out_);
        pl_tex_destroy(gpu_, &depth_);
        pl_tex_destroy(gpu_, &zero_mv_);
        if (sem_)
            pl_vulkan_sem_destroy(gpu_, &sem_);
    }
    if (pool_ && vkf_ && vk_) {
        vkf_->DeviceWaitIdle(vk_->device);
        vkf_->DestroyCommandPool(vk_->device, pool_, nullptr);
    }
    pool_ = VK_NULL_HANDLE;
    for (auto &c : cmd_)
        c = VK_NULL_HANDLE;
    for (auto &d : cmd_done_)
        d = 0;
    sem_val_ = 0;
    delete vkf_;
    vkf_ = nullptr;
    // Le module AMD reste chargé : le libérer pendant que le pilote garde des
    // pipelines créés par lui est risqué, et il ne coûte rien de le garder.
    usable_ = false;
    vk_ = nullptr;
    gpu_ = nullptr;
}

bool FsrFrameGen::ensureContext(int w, int h, pl_fmt fmt, bool hdr)
{
    if (ctx_ && ctx_w_ == w && ctx_h_ == h && ctx_fmt_ == fmt && ctx_hdr_ == hdr)
        return true;
    destroyContext();


    ffxCreateBackendVKDesc be = {};
    be.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_VK;
    be.deviceContext.vkDevice = vk_->device;
    be.deviceContext.vkPhysicalDevice = vk_->phys_device;
    be.deviceContext.vkDeviceProcAddr = vkf_->GetDeviceProcAddr;

    ffxCreateContextDescFrameGenerationVersion ver = {};
    ver.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION_VERSION;
    ver.version = FFX_FRAMEGENERATION_VERSION;

    ffxCreateContextDescFrameGeneration fg = {};
    fg.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION;
    fg.header.pNext = &be.header;
    be.header.pNext = &ver.header;
    fg.flags = hdr ? FFX_FRAMEGENERATION_ENABLE_HIGH_DYNAMIC_RANGE : 0u;
    fg.displaySize = { static_cast<uint32_t>(w), static_cast<uint32_t>(h) };
    fg.maxRenderSize = { static_cast<uint32_t>(w), static_cast<uint32_t>(h) };
    // Pour le backend Vulkan de libplacebo, la signature d'un pl_fmt est son VkFormat.
    fg.backBufferFormat = ffxApiGetSurfaceFormatVK(static_cast<VkFormat>(fmt->signature));

    ffxContext c = nullptr;
    const ffxReturnCode_t rc = reinterpret_cast<PfnFfxCreateContext>(fns_[0])(&c, &fg.header, nullptr);
    if (rc != FFX_API_RETURN_OK || !c) {
        const QString m = lastMessage();
        fail(QStringLiteral("création du contexte (code %1)%2").arg(rc).arg(m.isEmpty() ? QString() : QStringLiteral(" : ") + m));
        return false;
    }
    ctx_ = c;
    ctx_w_ = w;
    ctx_h_ = h;
    ctx_fmt_ = fmt;
    ctx_hdr_ = hdr;
    frame_id_ = 0;

    ffxConfigureDescGlobalDebug dbg = {};
    dbg.header.type = FFX_API_CONFIGURE_DESC_TYPE_GLOBALDEBUG;
    dbg.fpMessage = &ffxMessage;
    dbg.debugLevel = FFX_API_CONFIGURE_GLOBALDEBUG_LEVEL_ERRORS | FFX_API_CONFIGURE_GLOBALDEBUG_LEVEL_WARNINGS;
    reinterpret_cast<PfnFfxConfigure>(fns_[2])(&c, &dbg.header);

    ffxQueryGetProviderVersion q = {};
    q.header.type = FFX_API_QUERY_DESC_TYPE_GET_PROVIDER_VERSION;
    if (reinterpret_cast<PfnFfxQuery>(fns_[3])(&c, &q.header) == FFX_API_RETURN_OK && q.versionName)
        provider_ = QString::fromLatin1(q.versionName);
    qInfo("Farplay FSR: contexte %dx%d%s, fournisseur %s", w, h, hdr ? " HDR" : "", qPrintable(provider_));
    return true;
}

bool FsrFrameGen::ensureAux(int w, int h, int rw, int rh)
{
    auto make = [&](pl_tex *t, const char *fmtname, int tw, int th, bool storable, bool clear, float v) {
        if (*t && (*t)->params.w == tw && (*t)->params.h == th)
            return true;
        pl_tex_destroy(gpu_, t);
        pl_fmt f = pl_find_named_fmt(gpu_, fmtname);
        if (!f)
            return false;
        struct pl_tex_params p = {};
        p.w = tw;
        p.h = th;
        p.format = f;
        p.sampleable = true;
        p.storable = storable;
        p.blit_dst = clear;
        *t = pl_tex_create(gpu_, &p);
        if (!*t)
            return false;
        if (clear) {
            const float c[4] = { v, v, v, v };
            pl_tex_clear(gpu_, *t, c);
        }
        return true;
    };
    // Profondeur constante (scène « plate » à mi-distance) et vecteurs nuls,
    // comme pour une vidéo : FSR s'appuie alors sur son propre flux optique.
    // Sortie au format de l'entrée (8 bits sRGB en SDR, 10 bits PQ en HDR), stockable.
    if (!out_ || out_->params.w != w || out_->params.h != h || out_->params.format != out_fmt_) {
        pl_tex_destroy(gpu_, &out_);
        if (!out_fmt_ || !(out_fmt_->caps & PL_FMT_CAP_STORABLE))
            return false;
        struct pl_tex_params p = {};
        p.w = w;
        p.h = h;
        p.format = out_fmt_;
        p.sampleable = true;
        p.storable = true;
        out_ = pl_tex_create(gpu_, &p);
        if (!out_)
            return false;
    }
    return make(&depth_, "r32f", rw, rh, false, true, 0.9f)
        && make(&zero_mv_, "rg16f", rw, rh, false, true, 0.0f);
}

pl_tex FsrFrameGen::generate(pl_tex cur, bool reset, pl_tex mv, float mv_sx, float mv_sy,
                             bool hdr_pq, float max_nits, float frame_dt_ms, bool debug_view)
{
    if (!usable() || !cur)
        return nullptr;
    const int w = cur->params.w, h = cur->params.h;
    // Résolution de « rendu » (profondeur, vecteurs) : celle des vecteurs fournis,
    // sinon la moitié de l'affichage.
    const int rw = mv ? mv->params.w : (std::max)(16, w / 2);
    const int rh = mv ? mv->params.h : (std::max)(16, h / 2);
    out_fmt_ = cur->params.format;
    // FSR dimensionne ses ressources internes au premier envoi : si la taille ou
    // le format des vecteurs change (choix « Aucun » / « Flux Farplay »), on
    // recrée le contexte, sinon le nouveau réglage n'était pris qu'au redémarrage.
    pl_fmt mv_fmt = mv ? mv->params.format : nullptr;
    if (ctx_ && (rw != ctx_rw_ || rh != ctx_rh_ || mv_fmt != ctx_mv_fmt_))
        destroyContext();
    ctx_rw_ = rw;
    ctx_rh_ = rh;
    ctx_mv_fmt_ = mv_fmt;
    reset = reset || !ctx_; // contexte neuf : pas d'historique
    if (!ensureContext(w, h, cur->params.format, hdr_pq))
        return nullptr;
    if (!ensureAux(w, h, rw, rh)) {
        fail(QStringLiteral("textures auxiliaires (format de sortie non stockable ?)"));
        return nullptr;
    }
    if (!mv) {
        mv = zero_mv_;
        mv_sx = mv_sy = 1.0f;
    }

    // Command buffer libre (le plus ancien du tourniquet).
    const int ci = cmd_next_;
    cmd_next_ = (cmd_next_ + 1) % kCmd;
    if (cmd_done_[ci]) {
        VkSemaphoreWaitInfo wi = {};
        wi.sType = VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO;
        wi.semaphoreCount = 1;
        wi.pSemaphores = &sem_;
        wi.pValues = &cmd_done_[ci];
        if (vkf_->WaitSemaphores(vk_->device, &wi, 200000000ull) != VK_SUCCESS) {
            fail(QStringLiteral("GPU bloqué (attente du command buffer)"));
            return nullptr;
        }
    }
    VkCommandBuffer cb = cmd_[ci];

    // 1) libplacebo cède les textures (lecture par FSR) et signale le sémaphore.
    pl_tex held[4] = { cur, mv, depth_, out_ };
    uint64_t wait_vals[4] = {};
    int nheld = 0;
    for (int i = 0; i < 4; i++) {
        bool dup = false;
        for (int j = 0; j < i; j++)
            dup |= held[j] == held[i];
        if (dup)
            continue;
        struct pl_vulkan_hold_params hp = {};
        hp.tex = held[i];
        hp.layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        hp.qf = VK_QUEUE_FAMILY_IGNORED;
        hp.semaphore.sem = sem_;
        hp.semaphore.value = ++sem_val_;
        if (!pl_vulkan_hold_ex(gpu_, &hp)) {
            for (int k = 0; k < nheld; k++) {
                struct pl_vulkan_release_params rp = {};
                rp.tex = held[k];
                rp.layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
                rp.qf = VK_QUEUE_FAMILY_IGNORED;
                rp.semaphore.sem = sem_;
                rp.semaphore.value = wait_vals[k];
                pl_vulkan_release_ex(gpu_, &rp);
            }
            fail(QStringLiteral("texture non cessible par libplacebo"));
            return nullptr;
        }
        held[nheld] = held[i];
        wait_vals[nheld] = hp.semaphore.value;
        nheld++;
    }

    auto res = [&](pl_tex t, bool uav) {
        VkFormat f = VK_FORMAT_UNDEFINED;
        VkImageUsageFlags u = 0;
        VkImage img = pl_vulkan_unwrap(gpu_, t, &f, &u);
        FfxApiResource r = {};
        r.resource = reinterpret_cast<void *>(img);
        r.state = FFX_API_RESOURCE_STATE_PIXEL_COMPUTE_READ;
        r.description.type = FFX_API_RESOURCE_TYPE_TEXTURE2D;
        r.description.format = ffxApiGetSurfaceFormatVK(f);
        r.description.width = static_cast<uint32_t>(t->params.w);
        r.description.height = static_cast<uint32_t>(t->params.h);
        r.description.depth = 1;
        r.description.mipCount = 1;
        r.description.flags = FFX_API_RESOURCE_FLAGS_NONE;
        r.description.usage = uav ? FFX_API_RESOURCE_USAGE_UAV : FFX_API_RESOURCE_USAGE_READ_ONLY;
        return r;
    };

    // 2) FSR enregistre préparation + génération dans notre command buffer.
    vkf_->ResetCommandBuffer(cb, 0);
    VkCommandBufferBeginInfo bi = {};
    bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    bi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkf_->BeginCommandBuffer(cb, &bi);

    const uint64_t fid = ++frame_id_;
    ffxContext c = ctx_;
    bool ok = true;

    ffxConfigureDescFrameGeneration cfg = {};
    cfg.header.type = FFX_API_CONFIGURE_DESC_TYPE_FRAMEGENERATION;
    cfg.swapChain = nullptr;
    cfg.frameGenerationEnabled = true;
    cfg.allowAsyncWorkloads = false;
    cfg.flags = FFX_FRAMEGENERATION_FLAG_NO_SWAPCHAIN_CONTEXT_NOTIFY
        | (debug_view ? FFX_FRAMEGENERATION_FLAG_DRAW_DEBUG_VIEW : 0u);
    cfg.onlyPresentGenerated = false;
    cfg.generationRect = { 0, 0, w, h };
    cfg.frameID = fid;
    ffxReturnCode_t rc = reinterpret_cast<PfnFfxConfigure>(fns_[2])(&c, &cfg.header);
    ok &= rc == FFX_API_RETURN_OK;

    if (ok) {
        ffxDispatchDescFrameGenerationPrepareV2 prep = {};
        prep.header.type = FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION_PREPARE_V2;
        prep.frameID = fid;
        prep.flags = FFX_FRAMEGENERATION_FLAG_NO_SWAPCHAIN_CONTEXT_NOTIFY
        | (debug_view ? FFX_FRAMEGENERATION_FLAG_DRAW_DEBUG_VIEW : 0u);
        prep.commandList = cb;
        prep.renderSize = { static_cast<uint32_t>(rw), static_cast<uint32_t>(rh) };
        prep.jitterOffset = { 0.0f, 0.0f };
        prep.motionVectorScale = { mv_sx, mv_sy };
        prep.frameTimeDelta = frame_dt_ms;
        prep.reset = reset;
        // Caméra « neutre » : la vidéo n'en fournit pas.
        prep.cameraNear = 0.1f;
        prep.cameraFar = 1000.0f;
        prep.cameraFovAngleVertical = 1.0f;
        prep.viewSpaceToMetersFactor = 1.0f;
        prep.depth = res(depth_, false);
        prep.motionVectors = res(mv, false);
        const float up[3] = { 0.0f, 1.0f, 0.0f }, right[3] = { 1.0f, 0.0f, 0.0f }, fwd[3] = { 0.0f, 0.0f, -1.0f };
        std::memcpy(prep.cameraUp, up, sizeof(up));
        std::memcpy(prep.cameraRight, right, sizeof(right));
        std::memcpy(prep.cameraForward, fwd, sizeof(fwd));
        rc = reinterpret_cast<PfnFfxDispatch>(fns_[4])(&c, &prep.header);
        ok &= rc == FFX_API_RETURN_OK;
    }
    if (ok) {
        ffxDispatchDescFrameGeneration d = {};
        d.header.type = FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION;
        d.commandList = cb;
        d.presentColor = res(cur, false);
        d.outputs[0] = res(out_, true);
        d.numGeneratedFrames = 1;
        d.reset = reset;
        d.backbufferTransferFunction = hdr_pq ? FFX_API_BACKBUFFER_TRANSFER_FUNCTION_PQ : FFX_API_BACKBUFFER_TRANSFER_FUNCTION_SRGB;
        d.minMaxLuminance[0] = 0.0001f;
        d.minMaxLuminance[1] = max_nits > 0.0f ? max_nits : 1000.0f;
        d.generationRect = { 0, 0, w, h };
        d.frameID = fid;
        rc = reinterpret_cast<PfnFfxDispatch>(fns_[4])(&c, &d.header);
        ok &= rc == FFX_API_RETURN_OK;
    }
    vkf_->EndCommandBuffer(cb);

    // 3) Soumission (même file que libplacebo, verrouillée), puis restitution.
    const uint64_t done = ++sem_val_;
    if (ok) {
        VkPipelineStageFlags stages[4];
        VkSemaphore wsems[4];
        for (int i = 0; i < nheld; i++) {
            stages[i] = VK_PIPELINE_STAGE_ALL_COMMANDS_BIT;
            wsems[i] = sem_;
        }
        VkTimelineSemaphoreSubmitInfo ts = {};
        ts.sType = VK_STRUCTURE_TYPE_TIMELINE_SEMAPHORE_SUBMIT_INFO;
        ts.waitSemaphoreValueCount = static_cast<uint32_t>(nheld);
        ts.pWaitSemaphoreValues = wait_vals;
        ts.signalSemaphoreValueCount = 1;
        ts.pSignalSemaphoreValues = &done;
        VkSubmitInfo si = {};
        si.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        si.pNext = &ts;
        si.waitSemaphoreCount = static_cast<uint32_t>(nheld);
        si.pWaitSemaphores = wsems;
        si.pWaitDstStageMask = stages;
        si.commandBufferCount = 1;
        si.pCommandBuffers = &cb;
        si.signalSemaphoreCount = 1;
        si.pSignalSemaphores = &sem_;
        vk_->lock_queue(vk_, qf_, qidx_);
        const VkResult vr = vkf_->QueueSubmit(queue_, 1, &si, VK_NULL_HANDLE);
        vk_->unlock_queue(vk_, qf_, qidx_);
        if (vr != VK_SUCCESS) {
            ok = false;
            rc = 1000 + static_cast<int>(-vr);
        } else {
            cmd_done_[ci] = done;
        }
    }
    // En cas d'échec avant soumission, rien n'attend : on rend les textures sur
    // la dernière valeur déjà signalée par libplacebo.
    for (int k = 0; k < nheld; k++) {
        struct pl_vulkan_release_params rp = {};
        rp.tex = held[k];
        rp.layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        rp.qf = VK_QUEUE_FAMILY_IGNORED;
        rp.semaphore.sem = sem_;
        rp.semaphore.value = ok ? done : wait_vals[k];
        pl_vulkan_release_ex(gpu_, &rp);
    }
    if (!ok) {
        const QString m = lastMessage();
        fail(QStringLiteral("génération (code %1)%2").arg(rc).arg(m.isEmpty() ? QString() : QStringLiteral(" : ") + m));
        return nullptr;
    }
    return out_;
}

} // namespace farplay
