#!/bin/bash
# Version: 0.9.0
# Date   : 2017-08-16
#
# This script is inspired from https://github.com/AcuGIS/OpenTileServer
# Also inspired by documentation at https://wiki.debian.org/OSM/tileserver/jessie
#
# Simple tile server installation script with tilestache as main server for Debian
# Stretch (start with barbone install with ssh server only).
#
# This script will install open street map data and prepare the tilestache server
# to render the tiles directly via apache2
#
# The database will be stored under the defined user ("osm" by default) and the
# tiles will be stored in the user home at /home/{user}/www/tiles
#
# The script must be run as root
#
# Usage: ./opentileserverdebian.sh {pbf_url}"
#
# Example
# ./opentileserverdebian.sh http://download.geofabrik.de/north-america/us/delaware-latest.osm.pbf
# ./opentileserverdebian.sh http://download.geofabrik.de/europe/switzerland-latest.osm.pbf
# ./opentileserverdebian.sh https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf
#
# Licence
#
#    Copyright (C) 2017 LSI Media Sarl
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Change these values if needed
OSM_USER="osm" #linux and db user
OSM_DB="gis" #database name
VHOST=$(hostname -f)

# Internal variables
PBF_URL=${1}
PBF_FILE="/home/${OSM_USER}/OpenStreetMap/${PBF_URL##*/}"
UPDATE_URL="$(echo ${PBF_URL} | sed 's/latest.osm.pbf/updates/')"
if [[ ${PBF_URL} =~ "planet" ]]; then
    # For planet file, hard code the update url
    UPDATE_URL = "http://planet.openstreetmap.org/replication/day"
fi
NP=$(grep -c 'model name' /proc/cpuinfo)

#-------------------------------------------------------------------------------
#--- 0. Introduction
#-------------------------------------------------------------------------------
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {pbf_url}"; exit 1;
fi

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root";  exit 1;
fi

cat <<EOF

The values for the installation are
User          : ${OSM_USER}
Database name : ${OSM_DB}
Server name   : ${VHOST}
PBF URL       : ${PBF_URL}
To change these values, edit the script file

If the values are not correct, break this script (CTRL-C) now or wait 10s to continue
EOF
sleep 10s

#-------------------------------------------------------------------------------
#--- 1. Install package
#-------------------------------------------------------------------------------
echo ""
echo "1. Install needed packages"
echo "=========================="
export DEBIAN_FRONTEND=noninteractive
apt install -y -q ttf-unifont \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    fonts-thai-tlwg \
    postgresql \
    postgresql-contrib \
    postgresql-server-dev-all \
    postgis \
    osm2pgsql \
    osmosis \
    apache2 \
    libapache2-mod-wsgi \
    tilestache \
    javascript-common \
    libjs-leaflet
#--- prepare the answer for database and automatic download of shape files
echo "openstreetmap-carto openstreetmap-carto/database-name string ${OSM_DB}" | debconf-set-selections
echo "openstreetmap-carto-common openstreetmap-carto/fetch-data boolean true" | debconf-set-selections
apt install -y openstreetmap-carto
apt clean

# To avoid the label cut between tiles, add the avoid-edges in the default style
sed -i 's/<Map/<Map\ buffer-size=\"512\"\ /g' /usr/share/openstreetmap-carto/style.xml
sed -i 's/<ShieldSymbolizer/<ShieldSymbolizer\ avoid-edges=\"true\"\ /g' /usr/share/openstreetmap-carto/style.xml

#-------------------------------------------------------------------------------
#--- 2. Create system user
#-------------------------------------------------------------------------------
echo ""
echo "2. Create the user"
echo "===================="
if [ $(grep -c ${OSM_USER} /etc/passwd) -eq 0 ]; then	#if we don't have the OSM user
    # Password is disabled by default, so no access is possible
    useradd -m ${OSM_USER} -s /bin/bash -c "OpenStreetMap"
fi

#-------------------------------------------------------------------------------
#--- 3. Prepare database
#-------------------------------------------------------------------------------
echo ""
echo "3. Prepare database"
echo "==================="
# Create the database schema (as postgres user)
su postgres <<EOF
cd ~
createuser ${OSM_USER}
createdb -E UTF8 -O ${OSM_USER} ${OSM_DB}
psql -c "CREATE EXTENSION hstore;" -d ${OSM_DB}
psql -c "CREATE EXTENSION postgis;" -d ${OSM_DB}
EOF

#-------------------------------------------------------------------------------
#--- 4. Download file and inject in database
#-------------------------------------------------------------------------------
echo ""
echo "4. Populate database"
echo "======================"
let C_MEM=$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f4,7 -d' ' | tr ' ' '+')-200
su ${OSM_USER} <<EOF
mkdir -p /home/${OSM_USER}/OpenStreetMap
cd /home/${OSM_USER}/OpenStreetMap
# Download the latest state file first
wget -O state.txt ${UPDATE_URL}/state.txt
# Download main data file
wget ${PBF_URL}
# Prepare osmosis working dir and config file
osmosis --read-replication-interval-init workingDirectory=.
sed -i.save "s|#\?baseUrl=.*|baseUrl=${UPDATE_URL}|" configuration.txt
# Inject in database (could be very long for the planet)
osm2pgsql --slim -d ${OSM_DB} -C ${C_MEM} --number-processes ${NP} --hstore -S /usr/share/osm2pgsql/default.style ${PBF_FILE}
#rm ${PBF_FILE}
EOF

# Prepare the daily cron job for data update
cat > /etc/cron.daily/osm-update <<EOF
#!/bin/bash
# Switch to osm user
su ${OSM_USER} <<CRONEOF
cd /home/${OSM_USER}/OpenStreetMap
while [ \\\$(cat /home/${OSM_USER}/OpenStreetMap/state.txt | grep '^sequenceNumber=') != \\\$(curl -sL ${UPDATE_URL}/state.txt | grep '^sequenceNumber=') ]
do    
    echo "--- Updating data (Local: \$(cat /home/${OSM_USER}/OpenStreetMap/state.txt | grep '^sequenceNumber='), Online: \$(curl -sL ${UPDATE_URL}/state.txt | grep '^sequenceNumber='))"
    osmosis --read-replication-interval --simplify-change --write-xml-change changes.osc.gz
    # Get available memory just before we call osm2pgsql!
    let C_MEM=\\\$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f4,7 -d' ' | tr ' ' '+')-200
    osm2pgsql --append --slim -d ${OSM_DB} -C \\\${C_MEM} --number-processes ${NP} -e15 -o dirty_tiles.list --hstore changes.osc.gz
    sleep 2s
done
echo "--- Data is up to date."
CRONEOF
EOF
chmod +x /etc/cron.daily/osm-update

#-------------------------------------------------------------------------------
#--- 5. Configure tilestache
#-------------------------------------------------------------------------------
echo ""
echo "5. Configure tilestache and apache"
echo "=================================="
echo "Create default tilestache config file"
cat > /etc/tilestache.cfg <<EOF
{
  "cache":
  {
    "name": "Disk",
    "path": "/home/${OSM_USER}/www/tiles",
    "umask": "0022",
    "dirs": "portable"
  },
  "layers": 
  {
    "proxy":
    {
        "provider": {"name": "proxy", "provider": "OPENSTREETMAP" },
        "png options": {"palette": "http://tilestache.org/example-palette-openstreetmap-mapnik.act"},
        "cache lifespan": 2592000
    },
    "osm_tiles":
    {
        "provider" : { "name": "mapnik", "mapfile": "/usr/share/openstreetmap-carto/style.xml" },
        "preview":  { "lat": 0.0,  "lon": 0.0, "zoom": 1, "ext": "png" },
        "cache lifespan": 86400
    },
    "osm_tiles_grey":
    {
        "provider" : { "name": "mapnik", "mapfile": "/usr/share/openstreetmap-carto/style.xml" },
        "preview":  { "lat": 0.0,  "lon": 0.0, "zoom": 1, "ext": "png" },
        "cache lifespan": 86400,
        "pixel effect": { "name": "greyscale" }
    } 
  },
  "index": "/var/www/html/index.html",
  "logging": "info"
}
EOF

echo "Create default wsgi file"
cat > /var/www/tilestache.wsgi <<EOF
#!/usr/bin/python
import os, TileStache
application = TileStache.WSGITileServer('/etc/tilestache.cfg')
EOF

echo "Create a new virtual host"
cat > /etc/apache2/sites-available/tilestache.conf <<EOF
<VirtualHost *:80>
	ServerName ${VHOST}
	#ServerAlias tile

	DocumentRoot /var/www/html

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

	WSGIDaemonProcess tilestache processes=1 maximum-requests=500 threads=10 user=${OSM_USER}
    WSGIProcessGroup tilestache
	WSGIScriptAlias / /var/www/tilestache.wsgi
</VirtualHost>
EOF

echo "Prepare the demo leaflet page"
cat > /var/www/html/index.html <<EOF
<html>
<head>
  <title>Tile server demo</title>
  <link rel="stylesheet" href="/javascript/leaflet/leaflet.css"/>
  <script src="/javascript/leaflet/leaflet.js"></script>
  <style>
    #map{ height: 100% }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>

  // initialize the map
  // var map = L.map('map').setView([46.1931, 6.129162], 13);
  var map = L.map('map').setView([0, 0], 1);
  
  // load a tile layer
  var color = L.tileLayer('http://${VHOST}/osm_tiles/{z}/{x}/{y}.png',
    {
      attribution: 'Tiles by <a href="http://www.openstreetmap.org">OpenStreetMap</a>',
      maxZoom: 18,
      minZoom: 1
    });
  color.addTo(map);

  var grey = L.tileLayer('http://${VHOST}/osm_tiles_grey/{z}/{x}/{y}.png',
    {
      attribution: 'Tiles by <a href="http://www.openstreetmap.org">OpenStreetMap</a>',
      maxZoom: 18,
      minZoom: 1
    });
  
  var proxy = L.tileLayer('http://${VHOST}/proxy/{z}/{x}/{y}.png',
    {
      attribution: 'Tiles by <a href="http://www.openstreetmap.org">OpenStreetMap</a>',
      maxZoom: 18,
      minZoom: 1
    });
  
  var baseMaps = {
    "color": color,
    "grey": grey,
    "proxy": proxy
  };

  var overlays = { };

  L.control.layers(baseMaps,overlays, { "collapsed": false }).addTo(map);

  </script>
</body>
</html>
EOF

echo "Disable default virtual host"
a2dissite 000-default
echo "Enable tilestache host"
a2ensite tilestache
service apache2 restart

cat <<EOF
============================================
Installation is finished

You can find your an example at (leaflet)
http://${VHOST}
Change /var/www/html/index.html for the default location

The available tile stache alias are

Mapnik default style
http://${VHOST}/osm_tiles
http://${VHOST}/osm_tiles_grey

Proxy to tile.openstreetmap.ch
http://${VHOST}/proxy

The rendered/downloaded tiles are stored in
/home/${OSM_USER}/www/tiles

The main tilestache config is
/etc/tilestache.cfg
EOF
