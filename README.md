# SwiftHorizons

Swift wrapper for the NASA Horizon telnet service

# background

Source [here](https://ssd.jpl.nasa.gov/horizons/)

The JPL Horizons on-line solar system data and ephemeris computation service provides access to key solar system data and flexible production of highly accurate ephemerides for solar system objects 
(1,259,976 asteroids, 3,846 comets, 212 planetary satellites [includes satellites of Earth and dwarf planet Pluto], 8 planets, the Sun, L1, L2, select spacecraft, and system barycenters).
 Horizons is provided by the Solar System Dynamics Group of the  [Jet propulsion Laboratory](https://www.jpl.nasa.gov)

This swift wrapper allows simple single and multi target requests to be contained in a HorizonsTarget object which stores:
* A list of target objects with:
    * object id
    * request parameters
    * physical properties (WIP)
    * ephemeride: list of each time unit in given coordinates


 