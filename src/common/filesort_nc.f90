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

subroutine filesort_nc

!       check and sort felt file contents

!       unsorted list of files and timesteps with data:
!         iavail(n)%aYear: year    )
!         iavail(n)%aMonth: month   ) Time of analysis
!         iavail(n)%aDay: day     ) (not valid time of forecast)
!         iavail(n)%aHour: hour    )
!         iavail(n)%fcHour: forecast hour
!         iavail(n)%fileNo: file no. (in filename array)
!         iavail(n)%fileType: 1=model level  2=surface  3=both
!         iavail(n)%oHour: offset in hours from first (sorted) timestep
!         iavail(n)%nAvail: pointer to next forward  (time) data
!         iavail(n)%pAvail: pointer to next backward (time) data
!                   n=1,navail

!       pointers to lists in iavail:
!         kavail(1): pointer to first forward  sorted timestep
!         kavail(2): pointer to first backward sorted timestep

  USE DateCalc
  USE fileInfoML
  USE snapfilML
  USE snapgrdML
  USE snapfldML
  USE snapmetML, ONLY: start4d, count4d, xwindv, has_dummy_dim
  USE snapdebugML
!      USE snapmetML, only:
#if defined(DRHOOK)
  USE PARKIND1  ,ONLY : JPIM     ,JPRB
  USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
#endif
  implicit none
#if defined(DRHOOK)
  REAL(KIND=JPRB) :: ZHOOK_HANDLE ! Stack variable i.e. do not use SAVE
#endif
        
! netcdf
  include 'netcdf.inc'

  integer :: i, j, ncid, nf, varid, dimid, tsize, ierror
  real(kind=8) times(mavail)
  integer :: zeroHour, tunitLen, status, count_nan
  integer(kind=8) eTimes(mavail)
  integer(kind=8) :: add_offset, scalef
  integer, dimension(6) :: dateTime
  character(80) :: tunits

#if defined(DRHOOK)
! Before the very first statement
  IF (LHOOK) CALL DR_HOOK('FILESORT_NC',0,ZHOOK_HANDLE)
#endif

! position in iavail
  navail = 0
! loop over all file-names
  do nf = 1,nfilef
  ! get the time steps from the files "time" variable
    status = nf_open(filef(nf), NF_NOWRITE, ncid)
    if(status /= nf_noerr) then
      write(*,*) "cannot open ", trim(filef(nf)), ":", &
      trim(nf_strerror(status))
      write(9,*) "cannot open ", trim(filef(nf)), ":", &
      trim(nf_strerror(status))
      cycle
    endif
    call check(nf_inq_varid(ncid, "time", varid), "time")
    call check(nf_inq_dimid(ncid, "time", dimid), "tdim-id")
    call check(nf_inq_dimlen(ncid, dimid, tsize), "tdim-len")
    if (tsize > size(times)) then
      write(*,*) "to many time-steps in ", filef(nf), ": ", tsize
      call exit(1)
    end if
    call check(nf_get_vara_double(ncid, varid, (/1/), (/tsize/), &
    times), "time")
    call check(nf_inq_attlen(ncid, varid, "units", tunitLen))
    call check(nf_get_att_text(ncid, varid, "units", tunits), &
    "time units")
  ! shrink units-string to actual size
    tunits = tunits(:tunitLen)
    add_offset = timeUnitOffset(tunits)
    scalef = timeUnitScale(tunits)
    do i = 1, tsize
      call calc_2d_start_length(start4d, count4d, nx, ny, 1, &
      enspos, i, has_dummy_dim)
      call nfcheckload(ncid, xwindv, start4d, count4d, field1(1,1))
    ! test 4 arbitrary values in field
      count_nan = 0
      do j = 1, 4
        if (isnan(field1(j,j))) count_nan = count_nan + 1
      end do
      if (count_nan == 4) then
        write(*,*) xwindv, " at time ", i , " undefined, skipping"
        CYCLE
      end if
      navail = navail + 1
      if(navail > mavail) then
        if (navail == mavail) then
          write(9,*) 'WARNING : TOO MANY AVAILABLE TIME STEPS'
          write(9,*) '          no.,max(MAVAIL): ',navail,mavail
          write(9,*) '    CONTINUING WITH RECORDED DATA'
          write(6,*) 'WARNING : TOO MANY AVAILABLE TIME STEPS'
          write(6,*) '          max (MAVAIL): ',mavail
          write(6,*) '    CONTINUING WITH RECORDED DATA'
        end if
        navail=mavail
      end if
      eTimes(i) = times(i)*scalef + add_offset
      dateTime = epochToDate(eTimes(i))
    !          write(*,*) dateTime
      iavail(navail)%aYear = dateTime(6)
      iavail(navail)%aMonth = dateTime(5)
      iavail(navail)%aDay = dateTime(4)
      iavail(navail)%aHour = dateTime(3)
    !         iavail(n)%fcHour: forecast hour
      iavail(navail)%fcHour = 0
      iavail(navail)%fileNo = nf
    !         iavail(n)%fileType: 1=model level  2=surface  3=both
    !         currently not used
      iavail(navail)%fileType = 3
    ! in nc-mode: time-postion in file
      iavail(navail)%timePos = i
    !         iavail(n)%oHour: offset in hours from first (sorted) timestep
    !         but currently used to store the hours since 1970-01-01
      iavail(navail)%oHour = int(eTimes(i)/3600)
    !         iavail(n)%nAvail: pointer to next forward  (time) data
    !         iavail(n)%pAvail: pointer to next backward (time) data
    ! still to be set
      iavail(navail)%nAvail = 0
      iavail(navail)%pAvail = 0
    end do
  end do

! sorting time-steps, setting iavail 9, 10, kavail(1) and kavail(2)
! drop double occurances of time, using latest in input-list
  kavail(1) = 1
  kavail(2) = 1
  iavail(1)%pAvail = 0
  iavail(1)%nAvail = 0
  do i = 2, navail
  !       run back until time is >= existing time
    j = kavail(2)
    do while (j > 0 .AND. iavail(i)%oHour < iavail(j)%oHour)
      j = iavail(j)%pAvail
    end do
    if (j == kavail(2)) kavail(2) = i

    if (j == 0) then
    !         insert at beginning
      iavail(kavail(1))%pAvail = i
      iavail(i)%nAvail = kavail(1)
      iavail(i)%pAvail = 0
      kavail(1) = i
    else
      if (iavail(i)%oHour == iavail(j)%oHour) then
      !           replace position j with i (newer)
        if (iavail(i)%timePos==1 .AND. iavail(j)%timePos>1) then
        !  exception,  i is analysis time, j isn't so: keep j
        !  ignore this timestep if possible, but give next and previous
          iavail(i)%nAvail = iavail(j)%nAvail
          iavail(i)%pAvail = j
        !             reset first and last elements to j
          if (kavail(1) == i) kavail(1) = j
          if (kavail(2) == i) kavail(2) = j
        else
        !            replace j with i
          iavail(i)%nAvail = iavail(j)%nAvail
          iavail(i)%pAvail = iavail(j)%pAvail
        !             set next of previous if previous exists
          if (iavail(j)%pAvail /= 0) &
          iavail(iavail(j)%pAvail)%nAvail = i
        !             set previous of next if next exists
          if (iavail(j)%nAvail /= 0) &
          iavail(iavail(j)%nAvail)%pAvail = i
        !             reset first and last elements to i
          if (kavail(1) == j) kavail(1) = i
          if (kavail(2) == j) kavail(2) = i
        end if
      else
      ! insert i as successor to j
        iavail(i)%nAvail = iavail(j)%nAvail
        iavail(j)%nAvail = i
        iavail(i)%pAvail = j
        if (iavail(i)%nAvail /= 0) &
        iavail(iavail(i)%nAvail)%pAvail = i
        if (kavail(2) == j) kavail(2) = i
      end if
    end if
  end do


!..time range

  do i=1,2
    itimer(1,i)=iavail(kavail(i))%aYear
    itimer(2,i)=iavail(kavail(i))%aMonth
    itimer(3,i)=iavail(kavail(i))%aDay
    itimer(4,i)=iavail(kavail(i))%aHour
    itimer(5,i)=iavail(kavail(i))%fcHour
  end do

!..get valid time (with forecast=0)
  call vtime(itimer(1,1),ierror)
  call vtime(itimer(1,2),ierror)

!..adjust hours to hours since first available time
  zeroHour = iavail(kavail(1))%oHour
  do i=1,navail
    iavail(i)%oHour = iavail(i)%oHour - zeroHour
  end do

  if(idebug == 1) then
    write(9,*)
    write(9,*) 'FILESORT------------------------------------------'
  !..debug message of forward list
    j = kavail(1)
    do while (j > 0)
      write(9,*) "file info forward",j,": ",iavail(j)%aYear, &
      iavail(j)%aMonth, &
      iavail(j)%aDay,iavail(j)%aHour,trim(filef(iavail(j)%fileNo))
      j = iavail(j)%nAvail
    end do

    write(9,*)
    write(9,*) 'FILESORT--backward--------------------------------'
    j = kavail(2)
    do while (j > 0)
      write(9,*) "file info backward",j,": ",iavail(j)%aYear, &
      iavail(j)%aMonth, &
      iavail(j)%aDay,iavail(j)%aHour,trim(filef(iavail(j)%fileNo))
      j = iavail(j)%pAvail
    end do
  end if


#if defined(DRHOOK)
! Before the return statement
  IF (LHOOK) CALL DR_HOOK('FILESORT_NC',1,ZHOOK_HANDLE)
#endif
  RETURN
end subroutine filesort_nc