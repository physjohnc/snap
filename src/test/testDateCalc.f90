! gfortran testDateCalc.f90 -I../naccident/ ../naccident/dateCalc.o -o testDateCalc
program testDateCalc
  use DateCalc
  implicit none

  integer :: values(6)
  integer(kind=8) :: epochSeconds


  values = (/0,0,0, 1, 1, 1970 /)
  if (timegm(values) .ne. 0) then
    write(*,*) "wrong epoch: ", timegm(values)
    call exit(1)
  end if

  values = (/0,0,0, 1, 6, 1970 /)
  if (timegm(values) .ne. 13046400) then
    write(*,*) "wrong ", values, ": ", timegm(values)
    call exit(1)
  end if

  values = (/0,0,0, 6, 1, 1970 /)
  if (timegm(values) .ne. 5*24*3600) then
    write(*,*) "wrong ", values, ": ", timegm(values)
    call exit(1)
  end if

  values = (/0,0,0, 1, 1, 1980 /)
  if (timegm(values) .ne. 315532800) then
    write(*,*) "wrong ", values, ": ", timegm(values)
    write(*,*) "wrong epoch: ", timegm(values)
    call exit(1)
  end if

  values = (/0,0,0, 1, 1, 1969 /)
  if (timegm(values) .ne. -31536000) then
    write(*,*) "wrong ", values, ": ", timegm(values)
    write(*,*) "wrong epoch: ", timegm(values)
    call exit(1)
  end if

  values = (/0,0,0, 1, 1, 1960 /)
  if (timegm(values) .ne. -315619200) then
    write(*,*) "wrong ", values, ": ", timegm(values)
    write(*,*) "wrong epoch: ", timegm(values)
    call exit(1)
  end if


  values = (/21,51,9, 26, 6, 1973 /)
  if (timegm(values) .ne. 109936281) then
    write(*,*) "wrong ", values, ": ", timegm(values)
    call exit(1)
  end if

  values = parseDate("1973-06-26 09:51:21", "YYYY-MM-DD hh:mm:ss")
  if (timegm(values) .ne. 109936281) then
    write(*,*) "wrong 1973-06-26 09:51:21", parseDate("1973-06-26 09:51:21", "YYYY-MM-DD hh:mm:ss")
    call exit(1)
  end if
  values = parseDate("1973-06-26T09:51:21Z", "YYYY-MM-DD hh:mm:ss")
  if (timegm(values) .ne. 109936281) then
    write(*,*) "wrong 1973-06-26 09:51:21", parseDate("1973-06-26T09:51:21Z", "YYYY-MM-DD hh:mm:ss")
    call exit(1)
  end if



! TODO: missing leading whitespaces don't work yet
!  values = parseDate("1973-06-26 9:51:21", "YYYY-MM-DD hh:mm:ss")
!  if (timegm(values) .ne. 109936281) then
!    write(*,*) "wrong 1973-06-26 09:51:21", parseDate("1973-06-26 09:51:21", "YYYY-MM-DD hh:mm:ss")
!    call exit(1)
!  end if


  if (timeUnitScale("seconds since 1970-01-01 00:00:00") .ne. 1) then
    write(*,*) "error reading timeUnitScale('seconds since 1970-01-01 00:00:00'): ", &
                timeUnitScale("seconds since 1970-01-01 00:00:00")
    call exit(1)
  end if
  if (timeUnitOffset("seconds since 1970-01-01 00:00:00") .ne. 0) then
    write(*,*) "error reading timeUnitOffset('seconds since 1970-01-01 00:00:00'): ", &
                 timeUnitOffset("seconds since 1970-01-01 00:00:00")
    call exit(1)
  end if


end program testDateCalc