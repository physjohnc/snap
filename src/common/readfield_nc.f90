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

module readfield_ncML
  USE ftestML, only: ftest
  USE om2edotML, only: om2edot
  USE milibML, only: mapfield, hrdiff

  implicit none
  private

  public readfield_nc, check, nfcheckload, calc_2d_start_length

  interface nfcheckload
    module procedure nfcheckload1d, nfcheckload2d, nfcheckload3d
  end interface

  contains

!> Read fields from NetCDF files. (see readfield.f90 for felt-files)
subroutine readfield_nc(iunit, istep, nhleft, itimei, ihr1, ihr2, &
    itimefi,ierror)
  USE iso_fortran_env, only: error_unit
  USE particleML
  USE snapfilML
  USE snapfldML
  USE snapgrdML
  USE snapmetML
  USE snaptabML
  USE snapdebug, only: iulog, idebug
  USE netcdf
  USE snapdimML, only: nx, ny, nk
!> filehandle-unit (dummy)
  integer, intent(in) :: iunit
!> current timestep (always positive), negative istep means reset
  integer, intent(in) :: istep
!> remaining run-hours (negative for backward-calculations)
  integer, intent(inout) :: nhleft
!> minimal time-offset?
  integer, intent(inout) :: ihr1
!> maximal time-offset?
  integer, intent(inout) :: ihr2
!> initial time
  integer, intent(inout) :: itimei(5)
!> final time (output)
  integer, intent(out) :: itimefi(5)
!> error (output)
  integer, intent(out) :: ierror

! local variables
  integer, save :: ncid = 0
  integer, save :: ntav1, ntav2 = 0
  real, save :: t2thetafac(15000)
  character(len=1024), save :: file_name = ""

  integer :: i, j, k, n, ilevel, ierr1, ierr2, i1, i2
  integer :: itime(5,4), ihours(4)
  integer :: ihdif1, ihdif2, nhdiff
  real :: alev(nk), blev(nk), db, precip1, dxgrid, dygrid
  integer :: kk, ifb, kfb
  real :: dred, red, p, px, dp, p1, p2,ptop
  real, parameter :: rcp = r/cp
  real :: ptoptmp(1)
  real :: totalprec
  real :: unitScale
  real, parameter :: mean_surface_air_pressure = 1013.26

  integer :: timepos, timeposm1
  integer :: start3d(7), start4d(7), count3d(7), count4d(7)

  if (istep < 0) then
  ! set all 'save' variables to default values,
  ! ncid not needed, will close automaticall
    ntav1 = 0
    ntav2 = 0
    return
  end if

!..get time offset in hours (as iavail(n)%oHour)
  if (nhleft < 0) then
    ihr1 = -ihr1
    ihr2 = -ihr2
  end if
  ihours = [ihr1, ihr2, 0, nhleft]
  do n=1,4
    itime(:,n) = itimei
    itime(5,n) = itime(5,n) + ihours(n)
    call hrdiff(0,1,itimer(1,1),itime(1,n),ihours(n),ierr1,ierr2)
  end do
  ihdif1 = ihours(1)
  ihdif2 = ihours(2)

  write(iulog,*) '*READFIELD* Requested time: ',(itime(i,1),i=1,4)
  write(iulog,*) '                Time limit: ',(itime(i,2),i=1,4)
  write(iulog,*) '                 ihr1,ihr2: ', ihr1, ihr2


!..search in list of available timesteps with model level data
  if(ihdif1 > ihdif2) then
  !..using the backward list
    i = ihdif1
    ihdif1 = ihdif2
    ihdif2 = i
    kfb = 2
    ifb = 10
  else
    kfb = 1
    ifb = 9
  end if

  ntav1 = ntav2
  ntav2 = 0
  n = kavail(kfb)
  do while ((ntav2 == 0) .AND. (n > 0))
    if(iavail(n)%oHour >= ihdif1 .AND. &
    iavail(n)%oHour <= ihdif2) then
      ntav2 = n
    end if
  !..pointer to next timestep (possibly same time)
    if (ifb == 9) then
      n=iavail(n)%nAvail
    else
      n=iavail(n)%pAvail
    end if
  end do

  if(ntav2 < 1) then
    write(iulog,*) '*READFIELD* No model level data available'
    write(error_unit,*) '*READFIELD* No model level data available'
    ierror=1
    return
  end if


  if(idebug == 1) then
    write(iulog,*) 'MODEL LEVEL SEARCH LIST.   ntav2=',ntav2
    write(iulog,*) 'nx,ny,nk: ',nx,ny,nk
    write(iulog,*) 'istep,nhleft: ',istep,nhleft
    write(iulog,*) 'itimei(5), ihr1, ihr2:',(itimei(i),i=1,5),ihr1,ihr2
    write(iulog,*) 'kfb,ifb,ihdif1,ihdif2:',kfb,ifb,ihdif1,ihdif2
    write(iulog,fmt='(7(1x,i4),1x,i6,2i5)') (iavail(ntav2))
    flush(iulog)
  end if

! time between two inputs
! open the correct file, if required
  if (file_name /= filef(iavail(ntav2)%fileNo)) then
    if (ncid /= 0) then
      call check(nf90_close(ncid), "close ncid")
    end if
    file_name = filef(iavail(ntav2)%fileNo)
    call check(nf90_open(file_name, NF90_NOWRITE, ncid), file_name)
  end if

!     set timepos and nhdiff
  nhdiff = 3
  if (ntav1 /= 0) &
    nhdiff = abs(iavail(ntav2)%oHour - iavail(ntav1)%oHour)
  nprecip = nhdiff

  timepos = iavail(ntav2)%timePos
  timeposm1 = timepos ! Default: No deaccumulation possible
  if (ntav1 /= 0) then
    if (iavail(ntav2)%fileNo .eq. iavail(ntav1)%fileNo) then
      ! previous timestep in same file for deaccumulation
      timeposm1 = iavail(ntav1)%timePos
    endif
  endif
  itimefi(1) = iavail(ntav2)%aYear
  itimefi(2) = iavail(ntav2)%aMonth
  itimefi(3) = iavail(ntav2)%aDay
  itimefi(4) = iavail(ntav2)%aHour
  itimefi(5) = iavail(ntav2)%fcHour

  if(idebug == 1) then
    write(iulog,*) 'READING DATA FROM file=',trim(file_name)
    write(iulog,*) 'READING DATA FROM position=',timepos, ' for ', &
      itimefi, ', prev. position=',timeposm1,', hours:',nhdiff
  end if




  if( .TRUE. ) then
  !..move data from input time step 2 to 1

    u1 = u2
    v1 = v2
    w1 = w2
    t1 = t2
    hlevel1 = hlevel2
    hlayer1 = hlayer2

    ps1 = ps2
    bl1 = bl2
    hbl1 = hbl2

    if(imslp /= 0) then
      pmsl1 = pmsl2
    end if

  end if

  do k=nk-kadd,2,-1

  !..input model level no.
    ilevel=klevel(k)

    call calc_2d_start_length(start4d, count4d, nx, ny, ilevel, &
        enspos, timepos, has_dummy_dim)

  !..u
  !     Get the varid of the data variable, based on its name.
    call nfcheckload(ncid, xwindv, start4d, count4d, u2(:,:,k))

  !..v
    call nfcheckload(ncid, ywindv, start4d, count4d, v2(:,:,k))
  ! bug in chernobyl borders from destaggering
    where (v2 >= 1e+30)
      v2 = 0.0
    end where

  !..pot.temp. or abs.temp.
    call nfcheckload(ncid, pottempv, start4d, count4d, t2(:,:,k))


  !   TODO read ptop from file (only needed for sigma), but not in emep data
    ptop=100.
  !       if(ivcoor.eq.2) ptop=idata(19)
  !..p0 for hybrid loaded to ptop, ap is a * p0
    if (ivcoor /= 2 .AND. .NOT. ptopv == '') then
      call nfcheckload(ncid, ptopv, (/0/), (/1/), ptoptmp)
      ptop = ptoptmp(1)
    end if
  !..alevel (here) only for eta levels
    if ( .NOT. apv == '') then
      call nfcheckload(ncid, apv, (/ilevel/), (/1/), alev(k:k))
      call nfcheckload(ncid, bv, (/ilevel/), (/1/), blev(k:k))
      if (ivcoor /= 2 .AND. .NOT. ptopv == '') then
      !..p0 for hybrid loaded to ptop, ap is a * p0
        alev(k) = alev(k) * ptop
      end if
    ! TODO: check unit (here Pa -> hPa
      alev(k) = alev(k) / 100
    end if
    if ( .NOT. sigmav == '') then
    ! reusing blev(k) for sigma(k) later
      call nfcheckload(ncid, sigmav, (/ilevel/), (/1/), blev(k:k))
    end if

  !..sigma_dot/eta_dot (0 at surface)
  !..eta: eta_dot (or omega) stored in the same levels as u,v,th.
    if (sigmadotv == '') then
      w2 = 0
    else
      call nfcheckload(ncid, sigmadotv, &
          start4d, count4d, w2(:,:,k))
    end if

  end do ! k=nk-kadd,2,-1


!..surface pressure, 10m wind and possibly mean sea level pressure,
!..precipitation
  call calc_2d_start_length(start3d, count3d, nx, ny, -1, &
  enspos, timepos, has_dummy_dim)


! ps
  call nfcheckload(ncid, psv, start3d, count3d, ps2(:,:))
!  input ps, must be hPa, otherwise:
  if (nctype == 'arome' .OR. nctype == 'dmi_eps' .OR. &
  nctype == 'ec_det' .OR. nctype == 'h12_grib' .OR. &
  nctype == "ec_n1s") then
    ps2 = ps2*0.01
  endif


! u10m
! v10m
  if (.not.use_model_wind_for_10m) then
    call nfcheckload(ncid, xwind10mv, start3d, count3d, u2(:,:,1))
    call nfcheckload(ncid, ywind10mv, start3d, count3d, v2(:,:,1))
  else
    if (enspos >= 0) then
      call nfcheckload(ncid, xwindv, [1, 1, enspos+1, nk, timepos], &
          [nx, ny, 1, 1, 1], u2(:,:,1))
      call nfcheckload(ncid, ywindv, [1, 1, enspos+1, nk, timepos], &
          [nx, ny, 1, 1, 1], v2(:,:,1))
    else
      call nfcheckload(ncid, xwindv, [1, 1, nk, timepos], &
          [nx, ny, 1, 1], u2(:,:,1))
      call nfcheckload(ncid, ywindv, [1, 1, nk, timepos], &
          [nx, ny, 1, 1], v2(:,:,1))
    endif
  endif

!..mean sea level pressure, not used in computations,
!..(only for output to results file)
  if(imslp /= 0) then
    if ( .NOT. mslpv == '') then
      write(iulog,*) 'Mslp not found. Not important.'
      imslp=0
    else
      call nfcheckload(ncid, mslpv, start3d, count3d, pmsl2(:,:))
    end if
  end if

!..precipitation......................................................
  if (precaccumv /= '') then
  !..precipitation between input time 't1' and 't2'
    if (timepos /= 1) then
      call calc_2d_start_length(start3d, count3d, nx, ny, -1, &
          enspos, timeposm1, has_dummy_dim)
      call nfcheckload(ncid, precaccumv, &
          start3d, count3d, field1(:,:))

      call calc_2d_start_length(start3d, count3d, nx, ny, -1, &
          enspos, timepos, has_dummy_dim)
      call nfcheckload(ncid, precaccumv, &
          start3d, count3d, field2(:,:))

    !..the difference below may get negative due to different scaling
      do j=1,ny
        do i=1,nx
          precip1=max(field2(i,j)-field1(i,j),0.)/nhdiff
          precip(i,j,1:nprecip) = precip1
        end do
      end do
    end if
  else if (precstratiaccumv /= '') then
  ! accumulated stratiform and convective precipitation
  !..precipitation between input time 't1' and 't2'
    if (timepos /= 1) then
      call calc_2d_start_length(start3d, count3d, nx, ny, -1, &
          enspos, timeposm1, has_dummy_dim)
      call nfcheckload(ncid, precstratiaccumv, &
          start3d, count3d, field1)
      call nfcheckload(ncid, precconaccumv, &
          start3d, count3d, field2)
      call calc_2d_start_length(start3d, count3d, nx, ny, -1, &
          enspos, timepos, has_dummy_dim)
      call nfcheckload(ncid, precstratiaccumv, &
          start3d, count3d, field3)
      call nfcheckload(ncid, precconaccumv, &
          start3d, count3d, field4)
    !..the difference below may get negative due to different scaling
      unitScale = 1.
      if (nctype == 'ec_det' .or. nctype == "ec_n1s") unitScale = 1000.
      do j=1,ny
        do i=1,nx
          precip1=max(field3(i,j)+field4(i,j)- &
              (field1(i,j)+field2(i,j)),0.)/nhdiff
          precip(i,j,:) = precip1 * unitScale
        end do
      end do
    else
    ! timepos eq 1, check if precipitation already present / assume dummy step 0
      call calc_2d_start_length(start3d, count3d, nx, ny, -1, &
          enspos, timepos, has_dummy_dim)
      call nfcheckload(ncid, precstratiaccumv, &
          start3d, count3d, field3(:,:))
      call nfcheckload(ncid, precconaccumv, &
          start3d, count3d, field4(:,:))

      field1 = 0.0
      field2 = 0.0
      totalprec = sum(field3) + sum(field4)

      if (totalprec > 1e-5) then
      !..the difference below may get negative due to different scaling
        write(iulog,*) "found precip in first timestep, assuming ", &
            "empty 0 timestep to deaccumulate precip"
        unitScale = 1.
        if (nctype == 'ec_det' .or. nctype == "ec_n1s") unitScale = 1000.
        do j=1,ny
          do i=1,nx
            precip1=max(field3(i,j)+field4(i,j)- &
                (field1(i,j)+field2(i,j)),0.)/nhdiff
            precip(i,j,:) = precip1 * unitScale
          end do
        end do
      endif
    end if
  else
  !..non-accumulated emissions in stratiform an convective
    call nfcheckload(ncid, precstrativrt, &
        start3d, count3d, field1(:,:))
    call nfcheckload(ncid, precconvrt, &
        start3d, count3d, field2(:,:))

    do j=1,ny
      do i=1,nx
      !..precipitation must be larger 0, m/s -> mm/h
        precip1=max(field1(i,j)+field2(i,j),0.)*3600*1000
        precip(i,j,:) = precip1
      end do
    end do

  end if

! first time initialized data
  if(istep == 0) then

    do k=2,nk-kadd
      alevel(k)=alev(k)
      blevel(k)=blev(k)
    end do

    if(kadd > 0) then
      if(ivcoor == 2) then
      !..sigma levels ... blevel=sigma
        db=blevel(nk-kadd-1)-blevel(nk-kadd)
        db=max(db,blevel(nk-kadd)/float(kadd))
        do k=nk-kadd+1,nk
          blevel(k)=max(blevel(k-1)-db,0.)
        end do
      elseif(ivcoor == 10) then
      !..eta (hybrid) levels
        p1=alevel(nk-kadd)+blevel(nk-kadd)*1000.
        p2=alevel(nk-kadd-1)+blevel(nk-kadd-1)*1000.
        dp=p2-p1
        if(p1-dp*kadd < 10.) dp=(p1-10.)/kadd
        db=blevel(nk-kadd-1)-blevel(nk-kadd)
        db=max(db,blevel(nk-kadd)/float(kadd))
        do k=nk-kadd+1,nk
          p1=p1-dp
          blevel(k)=max(blevel(k-1)-db,0.)
          alevel(k)=p1-blevel(k)*1000.
        end do
      else
        write(error_unit,*) 'PROGRAM ERROR.  ivcoor= ',ivcoor
        error stop 255
      end if
    end if

    if(ivcoor == 2) then
    !..sigma levels (norlam)
      do k=2,nk
        alevel(k)=ptop*(1.-blevel(k))
      end do
    end if

  !..surface
    alevel(1)=0.
    blevel(1)=1.

    if(ivcoor == 2) then
    !..sigma levels ... vlevel=sigma
      vlevel = blevel
    elseif(ivcoor == 10) then
    !..eta (hybrid) levels ... vlevel=eta (eta as defined in Hirlam)
      vlevel = alevel/mean_surface_air_pressure + blevel
    else
      write(error_unit,*) 'PROGRAM ERROR.  ivcoor= ',ivcoor
      error stop 255
    end if

  !..half levels where height is found,
  !..alevel and blevel are in the middle of each layer
    ahalf(1)=alevel(1)
    bhalf(1)=blevel(1)
    vhalf(1)=vlevel(1)
  !..check if subselection of levels
    do k=2,nk-1
      if (klevel(k+1) /= klevel(k)-1) then
        manual_level_selection = .TRUE.
      endif
    end do
    do k=2,nk-1
      if ( .NOT. manual_level_selection) then
        ahalf(k)=alevel(k)+(alevel(k)-ahalf(k-1))
        bhalf(k)=blevel(k)+(blevel(k)-bhalf(k-1))
        vhalf(k)=ahalf(k)/mean_surface_air_pressure+bhalf(k)
      else
        ahalf(k)=(alevel(k)+alevel(k+1))*0.5
        bhalf(k)=(blevel(k)+blevel(k+1))*0.5
        vhalf(k)=ahalf(k)/mean_surface_air_pressure+bhalf(k)
      end if
    end do
    ahalf(nk)=alevel(nk)
    bhalf(nk)=blevel(nk)
    vhalf(nk)=vlevel(nk)

  !..compute map ratio
    call mapfield(1,0,igtype,gparam,nx,ny,xm,ym,&
        xm, & ! Ignored when icori = 0
        dxgrid,dygrid,ierror)
    if(ierror /= 0) then
      write(iulog,*) 'MAPFIELD ERROR. ierror= ',ierror
      write(error_unit,*) 'MAPFIELD ERROR. ierror= ',ierror
      error stop 255
    end if
    gparam(7)=dxgrid
    gparam(8)=dygrid
  !..size of each grid square (m**2)
    garea = (dxgrid/xm) * (dygrid/ym)
    dgarea = garea

    if (temp_is_abs) then
    ! create precomputed table for pressures between 0.1 and 1500hPa
      do i=1,size(t2thetafac)
        t2thetafac(i) = 1./((real(i)/10.*0.001)**rcp)
      end do
    end if

  ! end initialization
  end if

  if (temp_is_abs) then
  !..abs.temp. -> pot.temp.
    do k=2,nk-kadd
      do j=1,ny
        do i=1,nx
          p=alevel(k)+blevel(k)*ps2(i,j)
        ! t2thetafac is 50% faster, and less then 0.5% difference in theta
          t2(i,j,k)=t2(i,j,k) * t2thetafac(nint(p*10.+.5))
        ! 2(i,j,k)=t2(i,j,k)/((p*0.001)**rcp)
        end do
      end do
    end do
  end if

  if (sigmadot_is_omega) then
  !..omega -> etadot, or rather etadot derived from continuity-equation (mean of both)
    call om2edot
  else if (sigmadotv == '') then
  !..omega -> etadot, or rather etadot derived from continuity-equation
    call om2edot
  ! om2edot take means of omega (=0) and continuity-equation, -> use only continuity equation
    w2 = 2.0*w2
  end if

!..sigma_dot/eta_dot 0 at surface
  w2(:,:,1) = 0.0

!..no temperature at or near surface (not used, yet)
  t2(:,:,1) = -999.0
  if(kadd > 0) then
  !..levels added at the top
    dred=0.5/float(kadd)
    red=1.
    kk=nk-kadd
    do k=nk-kadd+1,nk
      red=red-dred
      u2(:,:,k) = u2(:,:,kk)
      v2(:,:,k) = v2(:,:,kk)
      w2(:,:,k) = w2(:,:,kk)*red
      t2(:,:,k) = t2(:,:,kk)
    end do
  end if

  if(nhleft < 0) then
  ! backward-calculation, switch sign of winds
    u2 = -u2
    v2 = -v2
    w2 = -w2
  end if


! test---------------------------------------------------------------
  write(iulog,*) 'k,k_model,alevel,blevel,vlevel,p,dp:'
  px=alevel(nk)+blevel(nk)*1000.
  do k=nk,1,-1
    p=alevel(k)+blevel(k)*1000.
    write(iulog,fmt='(1x,2i5,f9.2,2f9.5,f8.0,f6.0)') &
        k,klevel(k),alevel(k),blevel(k),vlevel(k),p,p-px
    px=p
  end do

! test---------------------------------------------------------------

  if(idebug == 1) then
    call ftest('u  ', u2, reverse_third_dim=.true.)
    call ftest('v  ', v2, reverse_third_dim=.true.)
    call ftest('w  ', w2, reverse_third_dim=.true.)
    call ftest('t  ', t2, reverse_third_dim=.true.)
    call ftest('ps ', ps2)
    if (istep > 0) &
      call ftest('pre', precip(:,:,1:nprecip))
  end if


  if (istep == 0) then
  ! test---------------------------------------------------------------
    write(iulog,*) 'k,ahalf,bhalf,vhalf,p,dp:'
    px=ahalf(nk)+bhalf(nk)*1000.
    do k=nk,1,-1
      p=ahalf(k)+bhalf(k)*1000.
      write(iulog,fmt='(1x,i5,f9.2,2f9.5,f8.0,f6.0)') &
          k,ahalf(k),bhalf(k),vhalf(k),p,p-px
      px=p
    end do
  ! test---------------------------------------------------------------

  !..level table for (vertical) interpolation
  !..(remember that fields are stored bottom to top
  !.. and that all parameters now are in the same levels)
    write(iulog,*) 'ivlevel:'
    write(iulog,*) 'k,i1,i2,vlevel(k+1),vlevel(k)'
    i2=-1
    do k=nk-1,1,-1
      i1=i2+1
      i2=vlevel(k)*10000.
      if(k == 1) i2=10000
      do i=i1,i2
        ivlevel(i)=k
      end do
      write(iulog,*) k,i1,i2,vlevel(k+1),vlevel(k)
    end do

  !..level table for concentration in each sigma/eta layer
  !..(layers here as in the input model, no '10m' layer,
  !.. but ordering bottom to top, reorder at time of output)
    write(iulog,*) 'ivlayer:'
    write(iulog,*) 'k,i1,i2,vhalf(k+1),vhalf(k)'
    i2=-1
    do k=nk-1,1,-1
      i1=i2+1
      i2=nint(vhalf(k)*10000.)
      if(k == 1) i2=10000
      do i=i1,i2
        ivlayer(i)=k
      end do
      write(iulog,*) k,i1,i2,vhalf(k+1),vhalf(k)
    end do
  end if

  return
end subroutine readfield_nc


!> calculate the start and length paramters for slicing
!> a 2d field from a 3-5d dataset
subroutine calc_2d_start_length(start, length, nx, ny, zpos, &
  enspos, tpos, has_2d_dummy_height)
  integer, intent (out) :: start(7), length(7)
  integer, intent (in) :: nx, ny, zpos, enspos, tpos
  logical, intent (in) :: has_2d_dummy_height
  integer :: pos

  start = 1
  length = 1

  length(1) = nx
  length(2) = ny

  pos = 2
! ensemble enspos given in C notation, e.g. first member = 0
  if (enspos >= 0) then
    pos = pos + 1
    start(pos) = enspos+1
  end if
! z
  if (zpos >= 1) then
    pos = pos + 1
    start(pos) = zpos
  elseif (has_2d_dummy_height) then
    pos = pos + 1
  end if
! time
  pos = pos + 1
  start(pos) = tpos

end subroutine calc_2d_start_length


subroutine check(status, errmsg)
  use netcdf
  integer, intent ( in) :: status
  character(len=*), intent(in), optional :: errmsg

  if(status /= NF90_NOERR) then
    if (present(errmsg)) then
      print *, trim(nf90_strerror(status)), ": ", trim(errmsg)
    else
      print *, trim(nf90_strerror(status))
    endif
    error stop 1
  endif
end subroutine check

subroutine fillscaleoffset(ncid, varid, fillvalue, scalefactor, offset, status)
  use iso_fortran_env, only: real32
  use netcdf
  implicit none

  integer, intent(in) :: ncid, varid
  real(kind=real32), intent(out) :: fillvalue, scalefactor, offset
  integer, intent(out) :: status

  status = nf90_get_att(ncid, varid, "_FillValue", fillvalue)
  if (status == NF90_ENOTATT) then
    fillvalue = NF90_FILL_FLOAT
  else if (status /= NF90_NOERR) then
    return
  endif

  status = nf90_get_att(ncid, varid, "scale_factor", scalefactor)
  if (status == NF90_ENOTATT) then
    scalefactor = 1
  else if (status /= NF90_NOERR) then
    return
  endif

  status = nf90_get_att(ncid, varid, "add_offset", offset)
  if (status == NF90_ENOTATT) then
    offset = 0
    status = NF90_NOERR
  else if (status /= NF90_NOERR) then
    return
  endif
end subroutine fillscaleoffset

subroutine nfcheckload1d(ncid, varname, start, length, field)
  use, intrinsic :: IEEE_ARITHMETIC
  use iso_fortran_env, only: real32
  use netcdf
  integer, intent(in) :: ncid, start(:), length(:)
  character(len=*), intent(in) :: varname
  real(real32), intent(out) :: field(:)

  real(real32) :: factor, offset, fillvalue
  integer :: varid, status

  call check(nf90_inq_varid(ncid, varname, varid), varname)
  call check(nf90_get_var(ncid, varid, field, start=start, count=length), varname)

  call fillscaleoffset(ncid, varid, fillvalue, factor, offset, status)
  call check(status)

  where (field == fillvalue)
    field = IEEE_VALUE(fillvalue, IEEE_QUIET_NAN)
  end where

  if (factor /= 1. .OR. offset /= 0.) then
    field = field*factor + offset
  end if
end subroutine nfcheckload1d

subroutine nfcheckload2d(ncid, varname, start, length, field)
  use, intrinsic :: IEEE_ARITHMETIC
  use iso_fortran_env, only: real32
  use netcdf
  integer, intent(in) :: ncid, start(:), length(:)
  character(len=*), intent(in) :: varname
  real(real32), intent(out) :: field(:,:)

  real(real32) :: factor, offset, fillvalue
  integer :: varid, status

  call check(nf90_inq_varid(ncid, varname, varid), varname)
  call check(nf90_get_var(ncid, varid, field, start=start, count=length), varname)

  call fillscaleoffset(ncid, varid, fillvalue, factor, offset, status)
  call check(status)

  where (field == fillvalue)
    field = IEEE_VALUE(fillvalue, IEEE_QUIET_NAN)
  end where

  if (factor /= 1. .OR. offset /= 0.) then
    field = field*factor + offset
  end if
end subroutine nfcheckload2d

subroutine nfcheckload3d(ncid, varname, start, length, field)
  use, intrinsic :: IEEE_ARITHMETIC
  use iso_fortran_env, only: real32
  use netcdf
  integer, intent(in) :: ncid, start(:), length(:)
  character(len=*), intent(in) :: varname
  real(real32), intent(out) :: field(:,:,:)

  real(real32) :: factor, offset, fillvalue
  integer :: varid, status

  call check(nf90_inq_varid(ncid, varname, varid), varname)
  call check(nf90_get_var(ncid, varid, field, start=start, count=length), varname)

  call fillscaleoffset(ncid, varid, fillvalue, factor, offset, status)
  call check(status)

  where (field == fillvalue)
    field = IEEE_VALUE(fillvalue, IEEE_QUIET_NAN)
  end where

  if (factor /= 1. .OR. offset /= 0.) then
    field = field*factor + offset
  end if
end subroutine nfcheckload3d
end module readfield_ncML
