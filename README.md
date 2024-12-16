# Docker postgis images

DISCLAIMER
============

**UNMAINTAINED/ABANDONED CODE / DO NOT USE**

Due to the new EU Cyber Resilience Act (as European Union), even if it was implied because there was no more activity, this repository is now explicitly declared unmaintained.

The content does not meet the new regulatory requirements and therefore cannot be deployed or distributed, especially in a European context.

This repository now remains online ONLY for public archiving, documentation and education purposes and we ask everyone to respect this.

As stated, the maintainers stopped development and therefore all support some time ago, and make this declaration on December 15, 2024.

We may also unpublish soon (as in the following monthes) any published ressources tied to the corpusops project (pypi, dockerhub, ansible-galaxy, the repositories).
So, please don't rely on it after March 15, 2025 and adapt whatever project which used this code.




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
