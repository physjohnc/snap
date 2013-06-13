      subroutine drydep2(tstep)
c
c  Purpose:  Compute dry deposition for each particle and each component
c            and store depositions in nearest gridpoint in a field
c  Method:   J.Bartnicki 2003
c
c
      implicit none
c
      include 'snapdim.inc'
      include 'snapgrd.inc'
      include 'snapfld.inc'
      include 'snappar.inc'
c
      real    tstep
c
      integer m,n,i,j,mm
      real    h,deprate,dep
c################################################################
      integer numdep
      real depmin,depmax,ratmin,ratmax,hblmin,hblmax
      double precision totinp,depsum,totsum
      numdep=0
      hblmin=+1.e+38
      hblmax=-1.e+38
      ratmin=+1.e+38
      ratmax=-1.e+38
      depmin=+1.e+38
      depmax=-1.e+38
      totinp=0.0d0
      depsum=0.0d0
      totsum=0.0d0
c################################################################
c
      do n=1,npart
c################################################################
        totinp=totinp+dble(pdata(9,n))
c################################################################
	m= icomp(n)
c######	if(kdrydep(m).eq.1 .and. pdata(3,n).lt.pdata(4,n)) then
	if(kdrydep(m).eq.1 .and. pdata(3,n).gt.pdata(4,n)) then
	  h=pdata(5,n)
c..gravityms=pdata(10,n)
ccc JB 30.04
c	  deprate= 1.0 - exp(-tstep*pdata(10,n)/h)
	  deprate= 1.0 - exp(-tstep*(pdata(10,n)+0.006)/h)	
          dep=deprate*pdata(9,n)
          pdata(9,n)=pdata(9,n)-dep
	  i=nint(pdata(1,n))
	  j=nint(pdata(2,n))
	  mm=iruncomp(m)
          depdry(i,j,mm)=depdry(i,j,mm)+dble(dep)
c################################################################
	  if(hblmin.gt.h) hblmin=h
	  if(hblmax.lt.h) hblmax=h
	  if(ratmin.gt.deprate) ratmin=deprate
	  if(ratmax.lt.deprate) ratmax=deprate
	  if(depmin.gt.dep) depmin=dep
	  if(depmax.lt.dep) depmax=dep
	  depsum=depsum+dble(dep)
	  numdep=numdep+1
c################################################################
	end if
c################################################################
        totsum=totsum+dble(pdata(9,n))
c################################################################
      end do
c
c################################################################
c      write(88,*) 'DRYDEP2 numdep,npart:  ',numdep,npart
c      write(88,*) 'DRYDEP2 totinp:        ',totinp
c      write(88,*) 'DRYDEP2 totsum,depsum: ',totsum,depsum
c      if(hblmin.le.hblmax)
c     +   write(88,*) 'DRYDEP2 hblmin,hblmax: ',hblmin,hblmax
c      if(ratmin.le.ratmax)
c     +   write(88,*) 'DRYDEP2 ratmin,ratmax: ',ratmin,ratmax
c      if(depmin.le.depmax)
c     +   write(88,*) 'DRYDEP2 depmin,depmax: ',depmin,depmax
c      write(88,*) '--------'
c################################################################
      return
      end