# handbroke-media-server
## Quick Reference
### Apps
| Application  |  address:port |
|---|---|
| SABnzbd  |  192.168.1.69:8080 |
| Jellyfin  | 192.168.1.69:8096 | 
| Sonarr (TV Shows)  | 192.168.1.69:8989 | 
| Radarr (Movies)  | 192.168.1.69:7878 | 
### Links
[NZBGeek (Indexer)](https://nzbgeek.info/)<br>
[Frugal (Provider)](https://billing.frugalusenet.com/login)

## Understanding Usenet (getting content)
In an over simplification, it's like ordering a pizza, but the pizzashop gets the ingredients from next door, on demand

**Hungry User**: The process begins when you decide you want specific content, much like a hungry person deciding they crave a pepperoni pizza.

**Personal Assistant (Sonarr/Radarr)**: Your automated software hears the request and immediately handles the logistics of finding and ordering the item for you.

**Pizza Menu (Indexer)**: The assistant searches the "menu" (a search engine called an Indexer) to find the correct "order slip" (NZB file) that lists exactly what is needed.

**Pizza Shop (sabnzbd)**: This order slip is handed to the "shop" (a download client like sabnzbd), which acts as the kitchen manager responsible for gathering the ingredients and assembling the final product.

**Mega Pizza Warehouse (Provider)**: The shop requests the raw ingredients (data parts) from the massive warehouse (the Usenet Service Provider) where all the files are actually stored.

**Delivery**: Once the shop retrieves and assembles all the ingredients, the finished pizza (your file) is delivered back to you, ready to enjoy.
