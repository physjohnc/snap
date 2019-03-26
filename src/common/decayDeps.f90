! SNAP: Servere Nuclear Accident Programme
! Copyright (C) 1992-2017   Norwegian Meteorological Institute

! This file is part of SNAP. SNAP is free software: you can
! redistribute it and/or modify it under the terms of the
! GNU General Public License as published by the
! Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.

! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.

! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <https://www.gnu.org/licenses/>.

subroutine decayDeps(tstep)
  USE snapfldML
  USE snapparML
  USE snapdimML, only: nx,ny,nk
!  Purpose:  Decrease radioactive contents of deposition fields
!            due to decay
!     NEEDS TO BE RUN BEFORE 1 decay

#if defined(DRHOOK)
  USE PARKIND1  ,ONLY : JPIM     ,JPRB
  USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
#endif
  implicit none

  real :: tstep

  integer :: i,j,m

  logical, save :: prepare = .TRUE. 


#if defined(DRHOOK)
! Before the very first statement
  IF (LHOOK) CALL DR_HOOK('DECAYDEPS',0,ZHOOK_HANDLE)
#endif

  if(prepare) then
  
  !..radioactive decay rate
    do m=1,ndefcomp
      if (kdecay(m) == 1) then
        decayrate(m)= exp(-log(2.0)*tstep/(halftime(m)*3600.))
      else
        decayrate(m)=1.0
      end if
    end do
  
    prepare= .FALSE. 
  end if

  do m=1,ndefcomp
    if(kdecay(m) == 1) then
      do j=1,ny
        do i=1,nx
          depdry(i,j,m)=depdry(i,j,m)*decayrate(m)
          depwet(i,j,m)=depwet(i,j,m)*decayrate(m)
          accdry(i,j,m)=accdry(i,j,m)*decayrate(m)
          accwet(i,j,m)=accwet(i,j,m)*decayrate(m)
        enddo
      enddo
    endif
  enddo
#if defined(DRHOOK)
!     before the return statement
  IF (LHOOK) CALL DR_HOOK('DECAYDEPS',1,ZHOOK_HANDLE)
#endif
  return
end subroutine decayDeps