### 📄 **`chromium-remote-debug/README.md`**

````markdown
# Chromium Remote Debug

Run Chromium browser inside a Neko container with remote debugging enabled and accessible from a browser. This app is useful for testing, automation, and accessing Chromium DevTools externally.

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
  --shm-size=2gb \
  --cap-add=SYS_ADMIN \
  ghcr.io/m1k1o/neko-apps/chromium-remote-debug:latest
```

This will:

* Expose the Neko web interface on port `8080`
* Expose Chromium DevTools on port `9223`

---

## ⚙️ Add Custom Chromium Flags

You can pass additional Chromium flags using the `NEKO_CHROMIUM_FLAGS` environment variable. Example:

```bash
docker run -it --rm \
  -p 8080:8080 \
  -p 9223:9223 \
  --shm-size=2gb \
  --cap-add=SYS_ADMIN \
  -e NEKO_CHROMIUM_FLAGS="--no-sandbox --no-zygote --disable-extensions --window-size=1920,1080" \
  ghcr.io/m1k1o/neko-apps/chromium-remote-debug:latest
```

---

## 🙏 Special Thanks

Thanks a ton [@Nefaris](https://github.com/Nefaris) 🙏!
Your [comment](https://github.com/m1k1o/neko/issues/391#issuecomment-3016080496) really helped me set this up successfully.

---

## 📖 Documentation

For more details about Neko apps and room management, see the [Neko Documentation](https://github.com/m1k1o/neko).

---