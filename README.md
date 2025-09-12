### 📄 **`chromium-remote-debug/README.md`**

````markdown
# Chromium Remote Debug - Minimal Edition

Run Chromium browser inside a Neko container with **no login interface** - direct browser access with remote debugging enabled. Optimized for minimal resource usage on low-resource machines.

## 🪶 Ultra-Minimal Features

- **No Login Required**: Direct access to browser view - no Neko interface
- **No UI Controls**: Clean browser-only experience
- **Auto-fullscreen**: Automatic fullscreen video display
- **Ultra-low resource usage**: Optimized for 4GB machines
- **CPU-only rendering**: No GPU acceleration for better compatibility
- **Reduced video quality**: 500kbps bitrate, 15fps for minimal bandwidth
- **Single-threaded encoding**: Minimal CPU impact
- **Disabled audio**: Audio streaming disabled to save resources
- **Anonymous access**: No user management or authentication

---

## 🚀 Build

Clone the `neko-apps` repository and build the image:  

```bash
git clone https://github.com/m1k1o/neko-apps.git
cd neko-apps

./build --application chromium-remote-debug --base_image ghcr.io/m1k1o/neko/base:latest
````

The image will be tagged as:

```
ghcr.io/m1k1o/neko-apps/chromium-remote-debug:latest
```

---

## ▶️ Run

Run the container with the following command:

```bash
docker run -it --rm \
  -p 8080:8080 \
  -p 9223:9223 \
  --shm-size=512mb \
  --cap-add=SYS_ADMIN \
  --memory=2g \
  --cpus=1.0 \
  ghcr.io/m1k1o/neko-apps/chromium-remote-debug:latest
```

This will:

* Expose the browser directly on port `8080` (no login required)
* Expose Chromium DevTools on port `9223`
* Use minimal resources (2GB RAM, 1 CPU core)
* Show only the browser - no Neko interface or controls

---

## ⚙️ Add Custom Chromium Flags

You can pass additional Chromium flags using the `NEKO_CHROMIUM_FLAGS` environment variable. Example:

```bash
docker run -it --rm \
  -p 8080:8080 \
  -p 9223:9223 \
  --shm-size=512mb \
  --cap-add=SYS_ADMIN \
  --memory=2g \
  --cpus=1.0 \
  -e NEKO_CHROMIUM_FLAGS="--window-size=800,600 --force-device-scale-factor=0.8" \
  ghcr.io/m1k1o/neko-apps/chromium-remote-debug:latest
```

## 🎛️ Video Quality Configuration

The video streaming is configured for ultra-low resource usage:

- **Resolution**: 1024x768
- **Frame Rate**: 15 FPS  
- **Bitrate**: 300 kbps
- **Encoding**: H.264 with ultrafast preset
- **Threading**: Single-threaded encoding

To modify video settings, edit the `neko.yaml` configuration file before building.

---

## 🙏 Special Thanks

Thanks a ton [@Nefaris](https://github.com/Nefaris) 🙏!
Your [comment](https://github.com/m1k1o/neko/issues/391#issuecomment-3016080496) really helped me set this up successfully.

---

## 📖 Documentation

For more details about Neko apps and room management, see the [Neko Documentation](https://github.com/m1k1o/neko).

---