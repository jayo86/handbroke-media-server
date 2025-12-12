# Quick Reference
## Apps
| Application  |  address:port |
|---|---|
| SABnzbd  |  192.168.1.69:8080 |
| Jellyfin  | 192.168.1.69:8096 | 
| Sonarr (TV Shows)  | 192.168.1.69:8989 | 
| Radarr (Movies)  | 192.168.1.69:7878 | 
## Links
[NZBGeek (Indexer)](https://nzbgeek.info/)<br>
[Frugal (Provider)](https://billing.frugalusenet.com/login)

# Understanding Usenet (getting content)
In an over simplification, it's like ordering a pizza, but the pizzashop gets the ingredients from next door, on demand:

![](/images/usenet_infograph.png)<br>

**Hungry User**: The process begins when you decide you want specific content, much like a hungry person deciding they crave a pepperoni pizza.

**Personal Assistant (Automation- Sonarr/Radarr)**: Your automated software hears the request and immediately handles the logistics of finding and ordering the item for you.

**Pizza Menu (Indexer- GeekNZB)**: The assistant searches the "menu" (a search engine called an Indexer) to find the correct "order slip" (NZB file) that lists exactly what is needed.

**Pizza Shop (Download Client- sabnzbd)**: This order slip is handed to the "shop" (a download client like sabnzbd), which acts as the kitchen manager responsible for gathering the ingredients and assembling the final product.

**Mega Pizza Warehouse (Provider- Frugal)**: The shop requests the raw ingredients (data parts) from the massive warehouse (the Usenet Service Provider) where all the files are actually stored.

**Delivery (Download Client- sabnzbd)**: Once the shop retrieves and assembles all the ingredients, the finished pizza (your file) is delivered back to you, ready to enjoy.

# Understanding Streaming

Movies are stored in highly compressed formats (think of a zipped file or a vacuum-packed suitcase) to save storage space, requiring them to be "unpacked" before they can be watched.

**Decoding** is simply your device unpacking this video to show it to you, which works perfectly if your TV or phone already knows how to read that specific video type. This is Jellyfin running 'DirectPlay'

However, if your device doesn't understand that specific format, Jellyfin must perform **Transcoding**, which acts like a real-time translator that unpacks the video and instantly repackages it into a new format your device can understand. Basically **decode** then **encode**, again in a different format that the device can understand. Transcoding is resource intensive, so dependant on compute power and compatbility. See Transcoding section.

Decoding is done by **codecs**. Think of a codec as a digital translator: just as you need a French translator to understand French and a Japanese translator for Japanese, your computer needs a specific codec to translate each type of decoding.

## Jellyfin DirectPlay
![](/images/directplay.png)<br>
Client (TV, mobile) decodes the video file

## Jellyfin Transcoding
![](/images/transcode.png)<br>
This is dependant on the power and capability of the processor and GPU.

- **Hardware transcoding** has the CPU and GPU working together to decode the files. Its built into the hardware, part of what they're designed to. Not only do they have the codecs programmed in, most CPUs will have hardware acceleration features to highly optimize the decoding process (eg Intel's QuickSync).

- Theres **Software transcoding** is the CPU running the decoding part via software instruction, like its emulatoring what hardware does, therefore it can be given codec instruction of **any** format. Not ideal unless its a very high-end fast CPU, so pretty much ignore that this is an option.
