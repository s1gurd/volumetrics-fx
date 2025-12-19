# volumetrics-fx
Couple of URP volumetric fog &amp; smoke effects, both full render feature and particle material with hlsl shader

<img width="424" height="268" alt="image" src="https://github.com/user-attachments/assets/7d2b2c1d-abd1-4438-b0a6-9f82f5da8cdd" />

This is NOT a production ready product, this is a small Proof-of-Concept I made in my spare time! 

Based on the solutions:
https://github.com/peeweek/Unity-URP-SmokeLighting
https://gist.github.com/HAliss/f84e3c482ea2ac9664a3048fa734093c

Start with Scenes/SampleScene.scene

Consists of 2 parts:
1. Full screen volumetric fog effect with support of 3D fog texture and all light types. It also can animate fog volume texture. See Material "VolumetricRaymarchFogSimple" and FullScreenPassRendererFeature in URP rendereк settings
2. Six-way lit particle effect with support for receiving shadows, creating fake volume and some other fancy stuff. Based on RLT & BBF Texture2DArrays. For details see prefabs in VFX/Effects folder and Material "Volumetric6WayLitParticles"

License and legal stuff:
Public Domain. You can take this and do whatever you want =))


