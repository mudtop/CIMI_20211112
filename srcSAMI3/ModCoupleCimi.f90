Module ModCoupleCimi
    implicit none 
    private !except

    logical, public :: DoCoupleCimi = .false.
    
    integer, public ::  iStartTime_I(7)  =(/1976,6,28,0,0,0,0/)
    
    integer, public :: iProc0CIMI,iProc0SAMI, iCommGlobal
    
    ! cimi Latitude (radians) and lon (radians) grid
    real, allocatable :: LatCimi_C(:),LonCimi_C(:)
    integer :: nLatCIMI, nLonCIMI
    
    ! cimi potential on cimi grid
    real, allocatable :: PotCIMI_C(:,:)
    
    !cimi potential on sami grid
    real, public, allocatable :: PotCimiOnSamiGrid_C(:,:)
    
    ! sami grid parameters for this module
    integer :: nLatSami, nLonSami
    real,allocatable    :: bLatSami(:,:), bLonSami(:,:)
    
  

    !public methods
    public :: sami_set_global_mpi
    public :: sami_put_init_from_cimi
    public :: sami_get_from_cimi
    public :: set_sami_grid_for_mod
  contains
    !==========================================================================
    ! call by all procs
    subroutine sami_set_global_mpi(iProc0CimiIN,iProc0SamiIN, iCommGlobalIN)
      integer, intent(in) ::iProc0CimiIN,iProc0SamiIN, iCommGlobalIN
      !------------------------------------------------------------------------
      iProc0CIMI=iProc0CimiIN
      iProc0Sami=iProc0SamiIN
      iCommGlobal=iCommGlobalIN

      ! Set the coupling to be true
      DoCoupleCimi=.true.
    end subroutine sami_set_global_mpi
    !========================================================================
    subroutine sami_put_init_from_cimi
      use ModSAMI, ONLY: iComm,iProc
      use ModMpi
      integer ::  iStartTimeCIMI_I(7),iError
      integer :: iStatus_I(MPI_STATUS_SIZE)
      !----------------------------------------------------------------------

      ! recieve and then bcast the starttime from cimi
      if (iProc == 0) call MPI_recv(iStartTime_I,7,MPI_INTEGER,iProc0CIMI,&
           1,iCommGlobal,iStatus_I,iError)
      call MPI_bcast(iStartTime_I,7,MPI_LOGICAL,0,iComm,iError)
      
      ! recieve grid size
      if (iProc == 0) call MPI_recv(nLatCIMI,1,MPI_INTEGER,iProc0CIMI,&
           2,iCommGlobal,iStatus_I,iError)

      if (iProc == 0) call MPI_recv(nLonCIMI,1,MPI_INTEGER,iProc0CIMI,&
           3,iCommGlobal,iStatus_I,iError)
      
      ! bcast grid size
      call MPI_bcast(nLatCIMI,1,MPI_LOGICAL,0,iComm,iError)
      call MPI_bcast(nLonCIMI,1,MPI_LOGICAL,0,iComm,iError)
      
      ! allocate CIMI grid
      allocate(LatCimi_C(nLatCIMI))
      allocate(LonCimi_C(nLonCIMI))

      if (iProc == 0) call MPI_recv(LatCimi_C,nLatCIMI,MPI_REAL,iProc0CIMI,&
           4,iCommGlobal,iStatus_I,iError)

      if (iProc == 0) call MPI_recv(LonCimi_C,nLonCIMI,MPI_REAL,iProc0CIMI,&
           5,iCommGlobal,iStatus_I,iError)

      ! allocate arrays that hold data from cimi
      allocate(PotCIMI_C(nLatCIMI,nLonCIMI))
      
    end subroutine sami_put_init_from_cimi
    
    !==========================================================================
    ! 
    subroutine sami_get_from_cimi
      use ModMPI
      use ModSAMI, ONLY: iComm,iProc
      integer :: iError
      integer :: iStatus_I(MPI_STATUS_SIZE)
      !------------------------------------------------------------------------
      
      !if(iProc ==0) write(*,*) 'sami_get_from_cimi',nLatCIMI,nLonCIMI
      ! Send the starttime from cimi to sami
      if(iProc ==0) call MPI_recv(PotCIMI_C,nLatCIMI*nLonCIMI,MPI_REAL,&
           iProc0CIMI,1,iCommGlobal,iStatus_I,iError)
      ! write out max and min of pot
      if(iProc ==0) write(*,*) 'Max and min of CIMI Potential: ', &
           maxval(PotCIMI_C), minval(PotCIMI_C)
      
      ! interpolate cimi potential to sami grid
      if(iProc ==0) call interpolate_cimi_to_sami
      
      if(iProc ==0) write(*,*) 'Max and min of CIMI Potential on Sami Grid: ', &
           maxval(PotCimiOnSamiGrid_C), minval(PotCimiOnSamiGrid_C)

      ! now bcast cimi potential on sami grid to all procs
      call MPI_bcast(PotCimiOnSamiGrid_C,nLatSami*nLonSami, &
           MPI_REAL,0,iComm,iError)
      
    end subroutine sami_get_from_cimi

    !==========================================================================
    subroutine interpolate_cimi_to_sami
      use ModInterpolate, ONLY: bilinear
      use ModNumConst,    ONLY: cDegToRad
      integer :: iLat, iLon
      real :: LatLon_D(2)
      
      do iLon = 1, nLonSami-1
         do iLat = 1, nLatSami
            !write(*,*) 'iLat,iLon,cDegToRad',iLat,iLon,cDegToRad
            LatLon_D(1) = bLatSami(iLat,iLon) * cDegToRad
            LatLon_D(2) = bLonSami(iLat,iLon) * cDegToRad
            
            !deal with coord transformation here

            if (LatLon_D(1) > maxval(LatCimi_C) .or. &
                 LatLon_D(1) < minval(LatCimi_C) ) then
               PotCimiOnSamiGrid_C(iLat,iLon) = 0.0
            else
               PotCimiOnSamiGrid_C(iLat,iLon) = &
                    bilinear(PotCIMI_C,1,nLatCIMI,1,nLonCIMI,LatLon_D, &
                    LatCimi_C,LonCimi_C,DoExtrapolate=.true.)
            endif
         enddo
      enddo
      
      ! add the ghost cell for potential
      PotCimiOnSamiGrid_C(:,nLonSami) = PotCimiOnSamiGrid_C(:,1) 
      call plot_coupled_values
      

    end subroutine interpolate_cimi_to_sami

    !==========================================================================
    subroutine set_sami_grid_for_mod(nzp1,nfp1,nlt,nnx,nny,blatpt,blonpt)
      integer, intent(in) :: nzp1, nfp1, nlt, nnx, nny
      real,    intent(in) :: blatpt(nzp1,nfp1,nlt),blonpt(nzp1,nfp1,nlt)


      allocate(bLatSami(nny,nnx-1),bLonSami(nny,nnx-1))
      
      nLonSami = nnx
      nLatSami = nny
      bLatSami = blatpt(nzp1,1:nny,1:nnx-1)
      bLonSami = blonpt(nzp1,1:nny,1:nnx-1)

      allocate(PotCimiOnSamiGrid_C(nLatSami,nLonSami))
    end subroutine set_sami_grid_for_mod

    !===========================================================================
    subroutine plot_coupled_values
      use ModIoUnit,    ONLY: UnitTmp_
      integer :: iLat, iLon

      open(UnitTmp_,FILE='SamiGridPot.dat')
      write(UnitTmp_,'(a)') &
           'VARIABLES = "Lat", "Lon", "Phi"'
      write(UnitTmp_,'(a,i3,a,i3,a)') 'Zone I=', nLatSami, &
           ', J=', nLonSami-1,', DATAPACKING=POINT'
      
      do iLon = 1, nLonSami-1
         do iLat = 1, nLatSami
            write(UnitTmp_,"(100es18.10)") bLatSami(iLat,iLon),&
                 bLonSami(iLat,iLon),PotCimiOnSamiGrid_C(iLat,iLon)
         enddo
      enddo
      close(UnitTmp_)

      open(UnitTmp_,FILE='CimiGridPot.dat')
      write(UnitTmp_,'(a)') &
           'VARIABLES = "Lat", "Lon", "Phi"'
      write(UnitTmp_,'(a,i3,a,i3,a)') 'Zone I=', nLatCimi, &
           ', J=', nLonCimi,', DATAPACKING=POINT'
      
      do iLon = 1, nLonCimi
         do iLat = 1, nLatCimi
            write(UnitTmp_,"(100es18.10)") LatCimi_C(iLat),&
                  LonCimi_C(iLon),PotCimi_C(iLat,iLon)
         enddo
      enddo
      close(UnitTmp_)

    end subroutine plot_coupled_values
    
  end Module ModCoupleCimi
  