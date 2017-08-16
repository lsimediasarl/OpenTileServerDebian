# Open tile server for Debian
Debian stretch script to install an OpenStreetMap tile server using

    -Tilestache
    -Default mapnik style
    -Postgres
    -Apache2
    -Leaflet demo page

## Introduction
After searching an easy way to install a tile server, we found the project
[OpenTileServer](https://github.com/AcuGIS/OpenTileServer) which was what
we needed.
The script was writen for Ubuntu but sadly not compatilbie with our main
deployed distribution, namely Debian, so we decided to write our own script.

As Debian has default package for the mapnik style and rendering/serving
tiles, the script is more simplier than the Ubuntu version

## Debian version
Only tested under Debian 9 (stretch), some package could be missing under other
release

## Script usage
<code>
./opentileserverdebian.sh  {pbf_url}

{pbf_url}: Complete PBF url from GeoFabrik (or other source)
</code>

## Tile server
When the installation is finished, a demo page is available under

    http://{HOST}
    
Change /var/www/html/index.html for the default location

The available tile stache alias are

Mapnik default style

    http://{HOST}/osm_tiles
    http://{HOST}/osm_tiles_grey

Proxy to tile.openstreetmap.ch

    http://{HOST}/proxy
    

The rendered/downloaded tiles are stored in

    /home/{USER}/www/tiles

The main tilestache config is

    /etc/tilestache.cfg
