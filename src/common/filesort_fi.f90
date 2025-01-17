! SNAP: Servere Nuclear Accident Programme
! Copyright (C) 1992-2021   Norwegian Meteorological Institute

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

module filesort_fiML
  implicit none
  private

  public filesort_fi

contains

!> check and sort netcdf file contents
  subroutine filesort_fi()
    USE iso_fortran_env, only: error_unit, real64, int64, int32
    use Fimex, only: FimexIO, AXIS_Lon, AXIS_Lat, AXIS_GeoX, AXIS_GeoY, AXIS_GeoZ, &
                     AXIS_Pressure, AXIS_Height, AXIS_Realization, AXIS_Time
    USE readfield_fiML, only: check
    USE snapfimexML, only: file_type, conf_file
    USE DateCalc, only: epochToDate
    USE Utils, only: itoa
    USE ieee_arithmetic, only: ieee_is_nan
    USE snapfilML, only: iavail, kavail, itimer, navail, nfilef, filef, spinup_steps
    USE snapfldML, only: enspos
    USE snapmetML, ONLY: met_params
    USE snapdebug, only: iulog, idebug
    USE snapdimML, only: mavail
    USE datetime, only: datetime_t, duration_t

    TYPE(FimexIO) :: fio
    integer(int32), dimension(:), allocatable :: start, length, atypes
    character(len=1024) :: time_var, varname
    integer :: i, j, t, ndims, nf, tsize, prev_avail_same_file
    real(real64), allocatable, target :: times(:)
    real(real64), allocatable, target :: field(:)
    integer :: zeroHour, status, count_nan
    integer :: dateTime(6)

! position in iavail
    navail = 0
! loop over all file-names
    do nf = 1, nfilef
      ! get the time steps from the files "time" variable
      ! using fio%open rather than fimex_open since projection does not matter here
      !  and might be expensive to set up
      status = fio%open (filef(nf), conf_file, file_type)
      if (status /= 0) then
        write (error_unit, *) "cannot open ", trim(filef(nf))
        write (iulog, *) "cannot open ", trim(filef(nf))
        cycle
      endif

      varname = met_params%xwindv
      ndims = fio%get_dimensions(varname)
      if (ndims <= 0) &
        call check(ndims, "can't make slicebuilder for "//TRIM(varname))

      if (allocated(start)) deallocate (start)
      allocate (start(ndims))
      if (allocated(length)) deallocate (length)
      allocate (length(ndims))
      if (allocated(atypes)) deallocate (atypes)
      allocate (atypes(ndims))
      call check(fio%get_dimension_start_size(start, length), "reading dim-sizes for "//TRIM(varname))
      call check(fio%get_axistypes(atypes), "reading dim-types for "//TRIM(varname))

      tsize = huge(tsize)
      DO i = 1, ndims
        SELECT CASE (atypes(i))
        CASE (AXIS_Time) ! full x-range
          tsize = length(i)
          time_var = fio%get_dimname(i)
        END SELECT
      END DO

      if (tsize > mavail) then
        write (error_unit, *) "to many time-steps in ", filef(nf), ": ", tsize
        error stop 1
      end if

      ndims = fio%get_dimensions(time_var)
      if (allocated(times)) deallocate (times)
      allocate (times(tsize))
      call check(fio%read (time_var, times, "seconds since 1970-01-01 00:00:00 +00:00"), "reading time variable")

      prev_avail_same_file = 0 ! unset
      do t = 1, tsize
        ndims = fio%get_dimensions(varname)
        DO i = 1, ndims
          SELECT CASE (atypes(i))
          CASE (AXIS_Time)
            call check(fio%reduce_dimension(fio%get_dimname(i), t - 1, 1), &
                       "reducing "//TRIM(fio%get_dimname(i))//" to "//itoa(t)//" for "//TRIM(varname))
          CASE (AXIS_GeoZ, AXIS_Pressure, AXIS_Height)
            call check(fio%reduce_dimension(fio%get_dimname(i), 0, 1), &
                       "reducing "//TRIM(fio%get_dimname(i))//" to 0 for "//TRIM(varname))
          CASE (AXIS_Realization)
            call check(fio%reduce_dimension(fio%get_dimname(i), enspos, 1), &
                       "reducing "//TRIM(fio%get_dimname(i))//" to 0 for "//TRIM(varname))
          CASE (AXIS_GeoX, AXIS_Lon)
            call check(fio%reduce_dimension(fio%get_dimname(i), 0, 4), &
                        "reducing "//TRIM(fio%get_dimname(i))//" to 4 for "//TRIM(varname))
          CASE (AXIS_GeoY, AXIS_Lat)
            call check(fio%reduce_dimension(fio%get_dimname(i), 0, 4), &
                        "reducing "//TRIM(fio%get_dimname(i))//" to 4 for "//TRIM(varname))
          END SELECT
        END DO
        if (.not. allocated(field)) allocate (field(4*4))
        status = fio%read (varname, field)
        if (status /= 0) then
          write (error_unit, *) "cannot read ", trim(varname), " in file ", trim(filef(nf))
          write (iulog, *) "cannot read ", trim(varname), " in file ", trim(filef(nf))
          cycle
        endif

        ! test 4 arbitrary values in field
        count_nan = 0
        do j = 1, 4
          if (ieee_is_nan(field(j*j))) count_nan = count_nan + 1
        end do
        if (count_nan == 4) then
          write (error_unit, *) met_params%xwindv, " at time ", i, " undefined, skipping"
          CYCLE
        end if
        navail = navail + 1
        if (navail >= mavail) then
          if (navail == mavail) then
            write (iulog, *) 'WARNING : TOO MANY AVAILABLE TIME STEPS'
            write (iulog, *) '          no.,max(MAVAIL): ', navail, mavail
            write (iulog, *) '    CONTINUING WITH RECORDED DATA'
            write (error_unit, *) 'WARNING : TOO MANY AVAILABLE TIME STEPS'
            write (error_unit, *) '          max (MAVAIL): ', mavail
            write (error_unit, *) '    CONTINUING WITH RECORDED DATA'
          end if
          navail = mavail
        end if
        dateTime = epochToDate(int(times(t), kind=int64))
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
        iavail(navail)%timePos = t
        !         iavail(n)%oHour: offset in hours from first (sorted) timestep
        !         but currently used to store the hours since 1970-01-01
        iavail(navail)%oHour = int(times(t)/3600)
        !         iavail(n)%nAvail: pointer to next forward  (time) data
        !         iavail(n)%pAvail: pointer to next backward (time) data
        ! still to be set
        iavail(navail)%nAvail = 0
        iavail(navail)%pAvail = 0
        iavail(navail)%pAvail_same_file = prev_avail_same_file
        prev_avail_same_file = navail
      end do
      status = fio%close()
      if (status /= 0) then
        write (error_unit, *) "cannot close ", trim(filef(nf))
        write (iulog, *) "cannot close ", trim(filef(nf))
        cycle
      endif
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
      do while (j > 0)
        if (.not. iavail(i)%oHour < iavail(j)%oHour) exit
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
          if (iavail(i)%timePos <= spinup_steps .AND. iavail(j)%timePos > spinup_steps) then
            !  exception,  i is analysis/spinup time, j isn't so: keep j
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
            if (iavail(j)%pAvail /= 0) then
              iavail(iavail(j)%pAvail)%nAvail = i
            endif
            !             set previous of next if next exists
            if (iavail(j)%nAvail /= 0) then
              iavail(iavail(j)%nAvail)%pAvail = i
            endif
            !             reset first and last elements to i
            if (kavail(1) == j) kavail(1) = i
            if (kavail(2) == j) kavail(2) = i
          end if
        else
          ! insert i as successor to j
          iavail(i)%nAvail = iavail(j)%nAvail
          iavail(j)%nAvail = i
          iavail(i)%pAvail = j
          if (iavail(i)%nAvail /= 0) then
            iavail(iavail(i)%nAvail)%pAvail = i
          endif
          if (kavail(2) == j) kavail(2) = i
        end if
      end if
    end do

!..time range

    do i = 1, 2
      itimer(i) = datetime_t(iavail(kavail(i))%aYear, &
                             iavail(kavail(i))%aMonth, &
                             iavail(kavail(i))%aDay, &
                             iavail(kavail(i))%aHour)
      itimer(i) = itimer(i) + duration_t(iavail(kavail(i))%fcHour)
    end do

!..adjust hours to hours since first available time
    zeroHour = iavail(kavail(1))%oHour
    do i = 1, navail
      iavail(i)%oHour = iavail(i)%oHour - zeroHour
    end do

    if (idebug == 1) then
      write (iulog, *)
      write (iulog, *) 'FILESORT------------------------------------------'
      !..debug message of forward list
      j = kavail(1)
      do while (j > 0)
        write (iulog, *) "file info forward", j, ": ", iavail(j)%aYear, &
          iavail(j)%aMonth, &
          iavail(j)%aDay, iavail(j)%aHour, trim(filef(iavail(j)%fileNo))
        j = iavail(j)%nAvail
      end do

      write (iulog, *)
      write (iulog, *) 'FILESORT--backward--------------------------------'
      j = kavail(2)
      do while (j > 0)
        write (iulog, *) "file info backward", j, ": ", iavail(j)%aYear, &
          iavail(j)%aMonth, &
          iavail(j)%aDay, iavail(j)%aHour, trim(filef(iavail(j)%fileNo))
        j = iavail(j)%pAvail
      end do
    end if

    RETURN
  end subroutine filesort_fi
end module filesort_fiML
