c-----------------------------------------------------------------------
c snapdim.inc
c
c..include file  - all parameter statements (model dimensions etc.)
c
c
c..nx,ny:  horizontal field dimensions (for computations)
c..nk:     number of levels
c
      integer nx,ny,nk
ccc   parameter (nx=121,ny=97,nk=14)
ccc   parameter (nx=127,ny=103,nk=19)
ccc   parameter (nx=188,ny=152,nk=32)
ccc      parameter (nx=468,ny=378,nk=41)
      parameter (nx=864,ny=698,nk=61)
c
c..mprecip: max no. og hourly precipitation fields
c           (and then the maximum hours between field input...)
c
      integer mprecip
      parameter (mprecip=12)
c
c
c..maxsiz: max. input field size (possibly larger than nx*ny)
c..ldata:  length of buffer for field input/output
c
      integer maxsiz,ldata
      parameter (maxsiz=nx*ny)
      parameter (ldata=20+maxsiz+50)
c
c
c..ENSEMBLE PROJECT.....................................
      integer nxep,nyep
c..disable ENSEMBLE PROJECT computation and output
ccc   parameter (nxep=1,nyep=1)
c..enable ENSEMBLE PROJECT computation and output
      parameter (nxep=151,nyep=91)
c.......................................................
c
c
c..SSV ARGOS............................................
      integer mxyargos
c..disable SSV ARGOS output
      parameter (mxyargos=1)
c..enable SSV ARGOS output, set maximum grid sizes
ccc   parameter (mxyargos=nx*ny)
c.......................................................
c
c
c..mplume:  max. no. of plume releases
c..mpart:   max. no. of particles, total in all plumes
c
      integer mplume,mpart
      parameter (mplume=50000)
      parameter (mpart =1000000)
ccc   parameter (mpart =300000)
c
c..mdefcomp: max. no. of components defined in input file (aerosol,gas,....)
c..mcomp:    max no. of components used in one run
c            (keep as small as "possible", it dimensions 2d/3d output fields)
c
      integer mdefcomp,mcomp
      parameter (mdefcomp=24 )
      parameter (mcomp=24)
c
c
c..mfilef: max. no. of input FELT files
c..mavail: max. no. of available timesteps with data
c
      integer mfilef,mavail
      parameter (mfilef=100)
      parameter (mavail=600)
c
      integer nxmc,nymc
c..use 1 or 2 below:
c..1: keep large arrays for concentration of each component in each layer
cc    parameter (nxmc=nx,nymc=ny)
c..2: remove large arrays for concentration
      parameter (nxmc=1,nymc=1)
c
      integer nxad,nyad
c..use 1 or 2 below:
c..1: keep additional fields (for output/graphics, not used in comp.)
      parameter (nxad=nx,nyad=ny)
c..2: remove additional fields
cc    parameter (nxad=1,nyad=1)
c
c
c..mbuffr:  max. length of buffer (for misc. reading from 'snap.input')
c..mrelpos: max. no. of release positions available (in list)
c..mtprof:  max. no. of timesteps in release profiles
c..mprepro: max. no. of steps in input precipitation probability table
c..mpretab: max. no. of steps in precipitation probability table
c
      integer mbuffr
      integer mrelpos
      integer mtprof
      integer mprepro,mpretab
      parameter (mbuffr=60)
      parameter (mrelpos=30)
      parameter (mtprof=20)
      parameter (mprepro=40,mpretab=500)
c
c
c..for gravity tables
c
      integer numtempvg,numpresvg
      parameter (numtempvg=  41)
      parameter (numpresvg=  25)
c
c
c..for graphics:
c..mlandfile: max. no. of landcontour (etc.) files
c
      integer mlandfile
      parameter (mlandfile=6)
c
c-----------------------------------------------------------------------