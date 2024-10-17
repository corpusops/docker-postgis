# Docker postgis images
- This repository provides tags for the following docker images:
    - [corpusops/postgis-bare](https://hub.docker.com/r/corpusops/postgis-bare)
- The additional tags from  [corpusops/docker-postgresql](https://github.com/corpusops/docker-postgresql) & [corpusops/docker-pgrouting](https://github.com/corpusops/docker-pgrouting) are based on those images:
    - pgrouting/ [corpusops/pgrouting-bare](https://hub.docker.com/r/corpusops/pgrouting-bare)
    - postgresql/ [corpusops/postgis](https://hub.docker.com/r/corpusops/postgis)
    - postgresql/ [corpusops/pgrouting](https://hub.docker.com/r/corpusops/pgrouting)


- Those images are based on
    [postgres](https://github.com/docker-library/postgres) and
    [mdillon/postgis](https://github.com/md5/docker-postgis) and

- And the reason for those to exist is to explicitly tag version tags and avoid non wanted production upgrades.

## Credits & documentation on image usage
- [And For **POSTGIS** based / inspired from this image](https://github.com/appropriate/docker-postgis)

## Supported tags
### postgis
- The following `corpusops/postgis-bare:<tag>` Docker Image tags are supported. <br/>
  The form is ``corpusops/postgis-bare:<POSTGIS_VER>-<POSTGIS_VER>``
    - 12: 12-2.5, 12-3
    - 13: 13-3
    - 14: 14-3
    - 15: 15-3
    - 16: 16-3
    - 17: 17-3

## notes:
- we must manually sync docker-postgis/*Dockerfiles* to local copy
