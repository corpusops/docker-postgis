
DISCLAIMER - ABANDONED/UNMAINTAINED CODE / DO NOT USE
=======================================================
While this repository has been inactive for some time, this formal notice, issued on **December 10, 2024**, serves as the official declaration to clarify the situation. Consequently, this repository and all associated resources (including related projects, code, documentation, and distributed packages such as Docker images, PyPI packages, etc.) are now explicitly declared **unmaintained** and **abandoned**.

I would like to remind everyone that this project’s free license has always been based on the principle that the software is provided "AS-IS", without any warranty or expectation of liability or maintenance from the maintainer.
As such, it is used solely at the user's own risk, with no warranty or liability from the maintainer, including but not limited to any damages arising from its use.

Due to the enactment of the Cyber Resilience Act (EU Regulation 2024/2847), which significantly alters the regulatory framework, including penalties of up to €15M, combined with its demands for **unpaid** and **indefinite** liability, it has become untenable for me to continue maintaining all my Open Source Projects as a natural person.
The new regulations impose personal liability risks and create an unacceptable burden, regardless of my personal situation now or in the future, particularly when the work is done voluntarily and without compensation.

**No further technical support, updates (including security patches), or maintenance, of any kind, will be provided.**

These resources may remain online, but solely for public archiving, documentation, and educational purposes.

Users are strongly advised not to use these resources in any active or production-related projects, and to seek alternative solutions that comply with the new legal requirements (EU CRA).

**Using these resources outside of these contexts is strictly prohibited and is done at your own risk.**

This project has been transfered to Makina Corpus <freesoftware-corpus.com> ( https://makina-corpus.com ). This project and its associated resources, including published resources related to this project (e.g., from PyPI, Docker Hub, GitHub, etc.), may be removed starting **March 15, 2025**, especially if the CRA’s risks remain disproportionate.

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
