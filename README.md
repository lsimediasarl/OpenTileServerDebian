# Open tile server for Debian
Debian stretch script to install an OpenStreetMap tile.

For Ubuntu version check [OpenTileServer](https://github.com/AcuGIS/OpenTileServer)
maintained by [opentileserver.org](https://opentileserver.org)

## Introduction
After searching an easy way to install a tile server, we found the project
[OpenTileServer](https://github.com/AcuGIS/OpenTileServer) which was what
we needed.
The script was writen for Ubuntu but sadly not compatible with our main
used distribution, namely Debian, so we decided to write our own script.

As Debian has default packages for the mapnik style and rendering/serving
tiles, the script is more simplier than the Ubuntu version

The used tools are

    -Tilestache
    -Default mapnik style
    -Postgres
    -Apache2
    -Leaflet demo page

## Debian version
Only tested under Debian 9 (stretch), some packages could be missing under other
releases

## Release
The script is an early stage and is in a work in progress sate, but it work well
in default context (barbone Debian Stretch install).

## Script usage
<code>
./opentileserverdebian.sh  {pbf_url}

{pbf_url}: Complete PBF url from GeoFabrik (or other source)
</code>

## OSM data update
The data are updated via osmosis, the tool is executed once a day with
a cron job. The updated data will be downloaded and merged in the database

( **experimental feature for the moment** )

## Tile server
When the installation is finished, a demo page is available under

    http://{HOST}
    
Change /var/www/html/index.html for fine tuning

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
