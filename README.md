# Open tile server for Debian
Debian stretch script to install an OpenStreetMap tile.

For Ubuntu version check [OpenTileServer](https://github.com/AcuGIS/OpenTileServer)
maintained by [opentileserver.org](https://opentileserver.org)

## Introduction
After searching an easy way to install a tile server, we found the project
[OpenTileServer](https://github.com/AcuGIS/OpenTileServer) which was what
we needed. The script was written for Ubuntu but sadly not compatible with 
Debian, so we decided to write our own script.

As Debian has default packages for the mapnik style and rendering/serving
tiles, the script is more simplier than the Ubuntu version

Two backend can be installed

### Tilestache
Tilestache is available by default in Debian, so this package is more simplier
to maintain and install, but it is slower than the mod_tile backend and lack
interesting features like marking "dirty" tiles to be re-rendered.

The used tools are

    -Tilestache
    -Default mapnik style
    -Postgres
    -Apache2
    -Leaflet demo page

### mod_tile
The mod_tile is not yet in stretch repository, but the Debian build is already prepared
in the git source tree of the mod_tile code, so it will be compiled and installed
as a standard debian package.

This backend is faster than Tilestache, but more complex to install and maintain
but has the advantage to have many useful features like re-rendering dirty tiles.

    -mod_tile
    -renderd
    -Default mapnik style    
    -Postgres
    -Apache2

## Debian version
Only tested under Debian 9 (stretch), some packages could be missing under other
releases

## Release
The script is an early stage and is in a work in progress sate, but it work well
in default context (barbone Debian Stretch install).

## Script usage
<code>
    ./opentileserverdebian.sh  {tilestache|mod_tile|none} {pbf_url}

    {tilestache|mod_tile|none} The backend to use (if none is specified only the data are imported)
    {pbf_url} complete PBF url from GeoFabrik (or other source)

Example

    ./opentileserverdebian.sh tilestache tilestache http://download.geofabrik.de/north-america/us/delaware-latest.osm.pbf
    ./opentileserverdebian.sh mod_tile http://download.geofabrik.de/europe/switzerland-latest.osm.pbf
    ./opentileserverdebian.sh none http://download.geofabrik.de/europe/switzerland-latest.osm.pbf
</code>

## OSM data update
The data are updated via osmosis, the tool is executed once a day with
a cron job. The updated data will be downloaded and merged in the database

( **experimental feature for the moment** )

## Tile server
When the installation is finished, a demo page is available under

    http://{HOST}
    

The important file to fine tune are

    /etc/renderd.conf (for mod_tile)
    /etc/tilestache.conf (for tilestache)
    
