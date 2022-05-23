# Warping for projection on a curved screen
Projecting an image on a curved screen with a projector introduces several geometric distortions, because most lenses are engineered to be used on plane screens. These distortions can be compensated by software.

This repository contains a GLSL/HLSL shader for MPV and MPC-HC. The shader has several variables to control the geometry correction which is then applied with high quality bicubic filtering. Lanczos was also evaluated, but gave no better results than bicubic and was discarded. The shader is best applied after scaling of the player/renderer. Tests revealed the best result in this case.

**Note: the GUI of both players will not be warped since it is overlayed after image processing.**

**Note 2: For MPV the target resolution has to be specified in the script, because there is no variable to get it from.**


## Usage
In MPV just put warping.glsl in a folder (e.g. "shaders") and reference it in mpv.conf like this:

glsl-shaders=shaders/warping.glsl


For MPC-HC put warping.hlsl in the sub folder "shaders" and add warping with option "Post-resize" in the options dialog.
![Alt text](mpc-hc_shader.png)

NOTICE: You have to define your native screen resolution in the shader.

## Example images
The shader supports the following distortions. All type of distorions can be combined. Please see the comments behind the variables inside the shader.

**Symmetrical curvature in both dimensions:**
![Alt text](example_hor_sym.jpg)

![Alt text](example_hor_vert_sym.jpg)

**Asymmetrical curvature:**
![Alt text](example_hor_asym.jpg)

**Bow distortion inside the curvature:**
![Alt text](example_hor_bow.jpg)

**Trapezoid:**
![Alt text](exmple_trapezoid.jpg)

**Linearity:**
![Alt text](example_linearity1.jpg)

![Alt text](example_linearity2.jpg)
