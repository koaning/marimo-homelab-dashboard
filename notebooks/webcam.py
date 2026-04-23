# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "marimo",
#     "wigglystuff",
#     "Pillow",
# ]
# [tool.marimo.opengraph]
# title = "Webcam Capture"
# description = "Capture frames from your webcam right in the browser"
# ///

import marimo

__generated_with = "0.23.2"
app = marimo.App(width="medium", auto_download=["html"])

with app.setup:
    import marimo as mo
    from wigglystuff import WebcamCapture


@app.cell
def _():
    mo.md(r"""
    # Webcam capture

    Live preview from your browser's webcam via the `WebcamCapture` widget from
    `wigglystuff`. Toggle **auto-capture** or hit the capture button; the latest
    frame flows back into Python as `image_base64` (and through the `get_pil()` /
    `get_bytes()` helpers).
    """)
    return


@app.cell
def _():
    cam = mo.ui.anywidget(WebcamCapture(interval_ms=1000))
    cam
    return (cam,)


@app.cell
def _():
    mo.md("""
    ## Latest frame
    """)
    return


@app.cell
def _(cam):
    if cam.image_base64:
        img = cam.widget.get_pil()
        img.thumbnail((480, 480))
        out = img
    else:
        out = mo.md("_No frame captured yet — press the capture button or enable auto-capture._")
    out
    return


@app.cell
def _(cam):
    mo.md(f"""
    ## Widget state

    - `capturing`: `{cam.capturing}`
    - `interval_ms`: `{cam.interval_ms}`
    - `facing_mode`: `{cam.facing_mode}`
    - `ready`: `{cam.ready}`
    - `error`: `{cam.error or "—"}`
    - `image_base64` size: `{len(cam.image_base64)} chars`
    """)
    return


if __name__ == "__main__":
    app.run()
