// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
pragma Singleton
import QtQuick
import QtCore
import org.streetpea.chiaking

QtObject {
    id: root

    readonly property var defaults: [
        { name: "GTA 6 · 30 fps + frame gen x2", fps: 30, frameGen: 1, multiplier: 2, upscaler: 1, sharpness: 70, deband: 1 },
        { name: "Jeu à 60 fps", fps: 60, frameGen: 0, multiplier: 2, upscaler: 1, sharpness: 70, deband: 1 }
    ]

    property var profiles: []
    readonly property var names: profiles.map(function(p) { return p.name })
    property string current: ""

    property Settings store: Settings {
        category: "FarplayProfiles"
        property string json: ""
        property string current: ""
    }

    function persist() {
        store.json = JSON.stringify(profiles)
        store.current = current
    }

    function find(name) {
        for (var i = 0; i < profiles.length; ++i)
            if (profiles[i].name === name) return profiles[i]
        return null
    }

    function apply(name) {
        var p = find(name)
        if (!p) return
        FarplayImage.upscaler = p.upscaler
        FarplayImage.sharpness = p.sharpness
        FarplayImage.deband = p.deband
        FarplayFrameGen.mode = p.frameGen
        FarplayFrameGen.multiplier = p.multiplier
        // fpsLocalPS5/fpsRemotePS5 valent directement 30 ou 60 (ChiakiVideoFPSPreset)
        var fps = p.fps === 60 ? 60 : 30
        Chiaki.settings.fpsLocalPS5 = fps
        Chiaki.settings.fpsRemotePS5 = fps
        current = name
        persist()
    }

    function saveCurrentAs(name) {
        name = (name || "").trim()
        if (name === "") return
        var p = {
            name: name,
            fps: Chiaki.settings.fpsLocalPS5 === 60 ? 60 : 30,
            frameGen: FarplayFrameGen.mode,
            multiplier: FarplayFrameGen.multiplier,
            upscaler: FarplayImage.upscaler,
            sharpness: FarplayImage.sharpness,
            deband: FarplayImage.deband
        }
        var list = profiles.filter(function(q) { return q.name !== name })
        list.push(p)
        profiles = list
        current = name
        persist()
    }

    function remove(name) {
        profiles = profiles.filter(function(q) { return q.name !== name })
        if (current === name) current = ""
        persist()
    }

    Component.onCompleted: {
        var list = []
        try { list = JSON.parse(store.json) } catch (e) { list = [] }
        if (!Array.isArray(list) || list.length === 0)
            list = defaults.slice()
        profiles = list
        current = store.current
        // Premier lancement : le profil GTA 6 est présenté comme actif (sans rien modifier)
        if (find(current) === null && profiles.length > 0)
            current = profiles[0].name
        if (store.json === "") persist()
    }
}
