# HandBroke Media Server
Good Luck, bra.
## Links
[Current Hardware Specs and Codec Support](current_hardware.md)<br>
[First Time Setup](bootstrap.md)<br>
[Update Sonarr and Radarr](arr_update.md)

| Application  |  address:port |
|---|---|
| SABnzbd  |  [192.168.1.69:8080](http://192.168/1/69:8080) |
| Jellyfin  | [192.168.1.69:8096](http://192.168.1.69:8096) | 
| Sonarr (TV Shows)  | [192.168.1.69:8989](http://192.168.1.69:8989) | 
| Radarr (Movies)  | [192.168.1.69:7878](http://192.168.1.69:7878) | 

### External Links
[NZBGeek (Indexer)](https://nzbgeek.info/)<br>
[Frugal (Provider)](https://billing.frugalusenet.com/login)<br>

# Understanding Usenet (getting content)
In an over simplification, it's like ordering a pizza, but the pizzashop gets the ingredients from next door, on demand:

![](/images/usenet_infograph.png)<br>

1. **Hungry User**: The process begins when you decide you want specific content, much like a hungry person deciding they crave a pepperoni pizza.

2. **Personal Assistant (Automation- Sonarr/Radarr)**: Your automated software hears the request and immediately handles the logistics of finding and ordering the item for you.

3. **Pizza Menu (Indexer- GeekNZB)**: The assistant searches the "menu" (a search engine called an Indexer) to find the correct "order slip" (NZB file) that lists exactly what is needed.

4. **Pizza Shop (Download Client- sabnzbd)**: This order slip is handed to the "shop" (a download client like sabnzbd), which acts as the kitchen manager responsible for gathering the ingredients and assembling the final product.

5. **Mega Pizza Warehouse (Provider- Frugal)**: The shop requests the raw ingredients (data parts) from the massive warehouse (the Usenet Service Provider) where all the files are actually stored.

6. **Delivery (Download Client- sabnzbd)**: Once the shop retrieves and assembles all the ingredients, the finished pizza (your file) is delivered back to you, ready to enjoy.

# Understanding Streaming

Movies are stored in highly compressed formats (think of a zipped file or a vacuum-packed suitcase) to save storage space, requiring them to be "unpacked" before they can be watched. This is **Decoding**.

## Decoding is done by codecs 
Think of a codec as a digital translator: just as you need a French translator to understand French and a Japanese translator for Japanese, your TV needs a specific codec to translate each type of decoding. 

## DirectPlay vs Transcoding
So this works perfectly if your TV or phone already has the right codec for that specific video type. This is Jellyfin running 'DirectPlay'.

However, if your device doesn't understand that specific format, Jellyfin must perform **Transcoding**, which in real-time unpacks the video and instantly repackages it into a new format your device can understand. Basically **decode** then **encode** again into a different format that the TV/phone can decode on its end. Transcoding is resource intensive, so dependant on compute power and compatbility. See Transcoding section.

## Jellyfin DirectPlay
![](/images/directplay.png)<br>
Client (TV, mobile) has the right codecs, so decodes the video file and plays.

## Jellyfin Transcoding
![](/images/transcode.png)<br>
Client (TV, mobile) doesn't have the right codecs, so needs to be decoded then encoded again into a format it can read (transcoding), and the video plays. This is dependant on the power and capability of the processor and GPU. An old budget shitty laptop may struggle with many types of encoding/decoding files.

- **Hardware transcoding** has the CPU and GPU working together to decode the encode the files. This is built into the hardware as part of what they're designed to do. Not only do they have (certain, depending on hardware) codecs programmed in, most CPUs will have hardware acceleration features to highly optimize the encoding/decoding process (eg Intel's QuickSync). Not all CPU/GPUs have all codecs.

- There's also **Software transcoding**, where the CPU running the decoding part via software instruction, like its emulating what hardware decoding/encoding does, therefore it can be given codec instruction of **any** format. Not ideal unless its a very high-end fast CPU, so pretty much ignore this is an option.

## Network Constraints
DirecPlay and Transcoding is meaningless if there isn't sufficient network bandwidth, which ofter overlooked.

## 4K Streaming Capacity & Network Performance Comparison

| File Type | Average Bitrate | Peak Bitrate | 100 Mbps LAN (Old Setup) | 1000 Mbps LAN (New Upgrade) |
| :--- | :--- | :--- | :--- | :--- |
| **4K REMUX**<br>(Full Blu-ray Quality) | ~65 Mbps | ~120-140 Mbps | **0 Streams (Unstable)**<br>*(Peaks >100Mbps cause buffering)* | **~6 to 8 Streams**<br>*(Plenty of headroom)* |
| **4K WEB-DL**<br>(High Quality Rip) | ~40 Mbps | ~60 Mbps | **1 to 2 Streams**<br>*(Risky if bitrate spikes)* | **~15 to 20 Streams** |
| **4K Compressed**<br>(Netflix/YouTube quality) | ~20 Mbps | ~30 Mbps | **3 to 4 Streams** | **~30+ Streams** |
