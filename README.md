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

# Understanding streaming

Movies are stored in highly compressed formats (think of a zipped file or a vacuum-packed suitcase) to save storage space, requiring them to be "unpacked" before they can be watched.

**Decoding** is simply your device unpacking this video to show it to you, which works perfectly if your TV or phone already knows how to read that specific video type. This is Jellyfin running 'DirectPlay'

However, if your device doesn't understand that specific format, Jellyfin must perform **Transcoding**, which acts like a real-time translator that unpacks the video and instantly repackages it into a new format your device can understand.

