# Current Hardware Specs & Compatibilty

## Server
Make/Model: Micro Dell OptiPlex 3060 

CPU: [Intel i5-8500T](https://www.intel.com/content/www/us/en/products/sku/129941/intel-core-i58500t-processor-9m-cache-up-to-3-50-ghz/specifications.html)<br>
Memory: 8GB RAM <br>
iGPU: Intel® UHD Graphics 630<br>
Storage: 256GB SSD (OS) + 2TB SSD<br>
Network: 1GBe LAN, WiFi<br>

## TV
Make/Model: TCL 65C755

As per [Intel's Encode and Decode Capabilities page](https://www.intel.com/content/www/us/en/developer/articles/technical/encode-and-decode-capabilities-for-7th-generation-intel-core-processors-and-newer.html) and [Display Specifications site](https://www.displayspecifications.com/en/model/3a5f3563)

### Codec Support Comparison: iGPU vs. TCL TV

| Hardware | JPEG | MJPEG | MPEG-2 (H.262) | MPEG-4 AVC (H.264) | MVC (H.265) | HEVC (H.265) 8-bit | HEVC (H.265) 10-bit | HEVC (H.265) 12-bit | VC1 | VP8 | VP9 8-bit | VP9 10-bit | VP9 12-bit | AV1 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Intel UHD 630 (iGPU)** | Yes | Yes | Yes | Yes | Yes | Yes | Yes | No | Decode only | Yes | Yes | Decode only | No | No |
| **TCL C755 (TV)** | Yes* | N/A | Likely No** | Yes | N/A | Yes | Yes | Likely No | No | N/A | Yes | Yes | N/A | Yes*** |

QuickSync Support: Yes

## Remarks
Codecs seen in black and white isn't the full story. As most bases were covered with the high-end TCL TV, **bottlenecks will occur with the old laptop's LAN connection (being at 100mbps)**. The server's NIC being at 1GBe/1000mpbs, will elleviate any networking issues.

Moreover, the upgrade to the GPU (i5-8500T) remains essential even with a fast network reasons such as:

- The "Spare Tire": While a fast network handles standard playback, the GPU acts as a mandatory safety net for high-quality files and remote viewing.
- Remote Streaming: Mobile data networks cannot handle full 4K bitrates (80Mbps). The GPU allows you to instantly shrink these massive files down to low-bandwidth streams (e.g., 4Mbps) for watching on phones or in hotels.
- The "Audio" Domino Effect: High-end audio formats (like TrueHD or DTS-HD) often aren't supported by TV apps. The server must convert the audio, which frequently forces a full video repackage that stresses the CPU.
- Subtitle "Burn-in": Image-based subtitles (PGS/VOBSUB found on Blu-rays) often cannot be overlaid by TV apps. The GPU is required to "burn" these images into the video frames, a heavy task that would otherwise crush the CPU.
