Module ModPrerunField
  implicit none
  real    :: DtRead=60.
  logical :: DoWritePrerun = .false., UsePrerun=.false.
contains
  !=============================================================================
  subroutine save_prerun(tSimulation)
    use ModGmCimi
    use ModTsyInput, ONLY: xnswa, vswa,bxw,byw,bzw 
    use ModIoUnit,  ONLY: UnitTmp_
    real, intent(in) :: tSimulation
    Character(len=100) :: NameFile             !output file name
    integer :: iTimeOut, iLat, iLon, iVar
    Logical, save    :: IsFirstCall =.true.
    !---------------------------------------------------------------------------
    
    if (IsFirstCall) then
       !create header file to save coupling setup determined in IM_wrapper
       open(UnitTmp_,file='IM/Prerun.h',status="replace")
       write(UnitTmp_,*) UseTotalRhoGm 
       write(UnitTmp_,*) UseTotalPGm   
       write(UnitTmp_,*) UseTotalPparGm
       write(UnitTmp_,*) UseMultiRhoGm 
       write(UnitTmp_,*) UseMultiPGm   
       write(UnitTmp_,*) UseMultiPparGm
       write(UnitTmp_,*) DoFeedbackPs  
       write(UnitTmp_,*) UsePeGm       
       write(UnitTmp_,*) rBodyGm
       write(UnitTmp_,*) iLatMin
       write(UnitTmp_,*) TotalRho_
       write(UnitTmp_,*) TotalP_
       write(UnitTmp_,*) TotalPpar_
       
       write(UnitTmp_,*) iBufferRho_I 
       write(UnitTmp_,*) iBufferP_I
       write(UnitTmp_,*) iBufferPpar_I   
       
       close(UnitTmp_)
       IsFirstCall =.false.
    endif

    ! Create Filename and open file
    iTimeOut=int(tSimulation)
    write(NameFile,"(a,i8.8,a)") &
         'IM/PrerunField_',iTimeOut,'.dat'   
    open(UnitTmp_,file=NameFile,status="replace", form="unformatted")

    ! Write out SW values
    write(UnitTmp_) xnswa(1), vswa(1), bxw(1), byw(1), bzw(1)

    ! Write out Kp values
    write(UnitTmp_) KpGm
    write(UnitTmp_) AeGm
    
    ! Write out nPoint and nVarBmin
    write(UnitTmp_) nPoint, nVarBmin

    ! Write out StateBmin_IIV
    do iLon = 1,nLon
       do iLat = 1,nLat
          write(UnitTmp_) StateBmin_IIV(iLat,iLon,1:nVarBmin)
       end do
    end do
    
    ! Write out StateLine_VI
    do iVar = 1,nVar
       write(UnitTmp_) StateLine_VI(iVar, 1:nPoint)
    end do
    
    close(UnitTmp_)

  end subroutine save_prerun
    
  !=============================================================================
  subroutine read_prerun(tSimulation)
    use ModGmCimi
    use ModTsyInput, ONLY: xnswa, vswa, bxw, byw, bzw
    use ModIoUnit,  ONLY: UnitTmp_
    real, intent(in) :: tSimulation
    integer          :: iTimeOut
    integer,save     :: iTimeOutPrev = -1
    integer          :: n, iLat, iLon, iVar
    Logical, save    :: IsFirstCall =.true.
    Character(len=100) :: NameFile             ! input file name
    !---------------------------------------------------------------------------

    ! Set filename for reading
    iTimeOut=int(floor(tSimulation/DtRead) * DtRead)
    
    if(iTimeOut == iTimeOutPrev) then
       return
    else
       iTimeOutPrev =iTimeOut
    end if 
    
    write(NameFile,"(a,i8.8,a)") &
         'IM/PrerunField_',iTimeOut,'.dat'   
    open(UnitTmp_,file=NameFile,status="old", form="unformatted")

    ! read SW values
    read(UnitTmp_) xnswa(1), vswa(1), bxw(1), byw(1), bzw(1)
    
    ! read Kp values
    read (UnitTmp_) KpGm
    if (KpGm>0) UseGmKp = .true.

    ! read Kp values
    read (UnitTmp_) AeGm
    if (KpGm>0) UseGmAe = .true.

    !  read nPoint and nVarBmin
    read(UnitTmp_) nPoint, nVarBmin

    ! Allocate StateLine and StateBmin
    if (allocated(StateLine_VI)) then
       deallocate(StateLine_VI,StateBmin_IIV)
    endif
    if (.not.allocated(StateLine_VI)) then
       allocate(StateLine_VI(nVar,nPoint),&
            StateBmin_IIV(nLat,nLon,nVarBmin))
    endif

    ! read StateBmin_IIV
    do iLon = 1,nLon
       do iLat = 1,nLat
          read(UnitTmp_) StateBmin_IIV(iLat,iLon,1:nVarBmin)
       end do
    end do
    
    ! read StateLine_VI
    do iVar = 1,nVar
       read(UnitTmp_) StateLine_VI(iVar, 1:nPoint)
    end do
    
    close(UnitTmp_)
    
    if (IsFirstCall) then
       ! create an index array on the first call
       n = 0
       do iLon = 1, nLon
          do iLat = 1, nLat
           n = n+1
           iLineIndex_II(iLon,iLat) = n
        end do
     end do
     UseGm = .true.

     !read header file to get coupling setup determined in IM_wrapper
     open(UnitTmp_,file='IM/Prerun.h',status="old")
     read(UnitTmp_,*) UseTotalRhoGm 
     read(UnitTmp_,*) UseTotalPGm   
     read(UnitTmp_,*) UseTotalPparGm
     read(UnitTmp_,*) UseMultiRhoGm 
     read(UnitTmp_,*) UseMultiPGm   
     read(UnitTmp_,*) UseMultiPparGm
     read(UnitTmp_,*) DoFeedbackPs  
     read(UnitTmp_,*) UsePeGm       
     read(UnitTmp_,*) rBodyGm
     read(UnitTmp_,*) iLatMin
     read(UnitTmp_,*) TotalRho_
     read(UnitTmp_,*) TotalP_
     read(UnitTmp_,*) TotalPpar_
     
     
     read(UnitTmp_,*) iBufferRho_I 
     read(UnitTmp_,*) iBufferP_I
     read(UnitTmp_,*) iBufferPpar_I   
     
     close(UnitTmp_)
     IsFirstCall =.false.
  endif

    
  end subroutine read_prerun

  !=============================================================================
  subroutine save_prerun_IE(tSimulation)
    use ModIeCimi, ONLY: Potential_II => Pot
    use ModIoUnit,  ONLY: UnitTmp_
    use ModCimiGrid,    ONLY: nLat => np, nLon => nt
    real, intent(in) :: tSimulation
    Character(len=100) :: NameFile             !output file name
    integer :: iTimeOut, iLat, iLon
    !---------------------------------------------------------------------------
    
    ! Create Filename and open file
    iTimeOut=int(tSimulation)
    write(NameFile,"(a,i8.8,a)") &
         'IM/PrerunIE_',iTimeOut,'.dat'   
    open(UnitTmp_,file=NameFile,status="replace", form="unformatted")

    ! Write out Potential_II
    do iLon = 1,nLon
          write(UnitTmp_) Potential_II(1:nLat,iLon)
    end do
    
    close(UnitTmp_)

  end subroutine save_prerun_IE
  
  !=============================================================================
  subroutine read_prerun_IE(tSimulation)
    use ModIeCimi, ONLY: Potential_II => Pot,UseIe
    use ModIoUnit,   ONLY: UnitTmp_
    use ModCimiGrid,    ONLY: nLat => np, nLon => nt

    real, intent(in) :: tSimulation
    integer          :: iTimeOut
    integer,save     :: iTimeOutPrev = -1
    integer          :: n, iLat, iLon
    Logical, save    :: IsFirstCall =.true.
    Character(len=100) :: NameFile             ! input file name
    !---------------------------------------------------------------------------

    ! Set filename for reading
    iTimeOut=int(floor(tSimulation/DtRead) * DtRead)
    
    if(iTimeOut == iTimeOutPrev) then
       return
    else
       iTimeOutPrev =iTimeOut
    end if 
    
    write(NameFile,"(a,i8.8,a)") &
         'IM/PrerunIE_',iTimeOut,'.dat'   
    open(UnitTmp_,file=NameFile,status="old", form="unformatted")

    ! read Potential_II
    do iLon = 1,nLon
          read(UnitTmp_) Potential_II(1:nLat,iLon)
    end do
    
    close(UnitTmp_)
    
    if (IsFirstCall) then
       IsFirstCall = .false.
       UseIE = .true.
    endif

    
end subroutine read_prerun_IE

end Module ModPrerunField
