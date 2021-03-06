subroutine amrex_probinit(init, name, namlen, problo, probhi) bind(c)

  use eos_module
  use eos_type_module
  use castro_error_module
  use network
  use probdata_module

  use amrex_fort_module, only : rt => amrex_real
  implicit none

  integer init, namlen
  integer name(namlen)
  real(rt)         problo(3), probhi(3)
  real(rt)         xn(nspec)

  type (eos_t) :: eos_state

  call probdata_init(name, namlen)

  split(1) = frac*(problo(1)+probhi(1))
  split(2) = frac*(problo(2)+probhi(2))
  split(3) = frac*(problo(3)+probhi(3))

  ! compute the internal energy (erg/cc) for the left and right state
  xn(:) = 0.0e0_rt
  xn(1) = 1.0e0_rt

  ! compute the internal energy (erg/cc)
  eos_state%rho = rho
  eos_state%p = p
  eos_state%T = 100000.e0_rt  ! initial guess
  eos_state%xn(:) = xn(:)

  call eos(eos_input_rp, eos_state)

  rhoe = rho*eos_state%e
  T  = eos_state % T

end subroutine amrex_probinit

subroutine ca_initdata(level, time, lo, hi, nscal, &
                       state, s_lo, s_hi, &
                       dx, xlo, xhi)

  use castro_error_module, only: castro_error
  use amrex_fort_module, only: rt => amrex_real
  use network, only: nspec
  use probdata_module
  use meth_params_module, only : NVAR, URHO, UMX, UMY, UMZ, UEDEN, UEINT, UTEMP, UFS
  use prob_params_module, only : problo
  use amrex_constants_module, only: ZERO

  implicit none

  integer,  intent(in   ) :: level, nscal
  integer,  intent(in   ) :: lo(3), hi(3)
  integer,  intent(in   ) :: s_lo(3), s_hi(3)
  real(rt), intent(in   ) :: xlo(3), xhi(3), time, dx(3)
  real(rt), intent(inout) :: state(s_lo(1):s_hi(1), s_lo(2):s_hi(2), s_lo(3):s_hi(3), NVAR)

  real(rt) :: xcen, ycen, zcen, r2
  integer  :: i, j, k

  do k = lo(3), hi(3)
     zcen = problo(3) + dx(3)*(dble(k) + 0.5e0_rt)

     do j = lo(2), hi(2)
        ycen = problo(2) + dx(2)*(dble(j) + 0.5e0_rt)

        do i = lo(1), hi(1)
           xcen = problo(1) + dx(1)*(dble(i) + 0.5e0_rt)

           state(i,j,k,URHO) = rho
           state(i,j,k,UMX) = rho*u_x
           state(i,j,k,UMY) = rho*u_y
           state(i,j,k,UMZ) = rho*u_z
           state(i,j,k,UEDEN) = rhoe + 0.5e0_rt*rho*(u_x**2+u_y**2+u_z**2) 
           state(i,j,k,UEINT) = rhoe
           state(i,j,k,UTEMP) = T

           r2 = ((xcen-0.5d0)**2 + (ycen-0.5d0)**2 + (zcen-0.5d0)**2) / 0.01d0
           state(i,j,k,UFS:UFS-1+nspec) = ZERO
           state(i,j,k,UFS)  = exp(-r2)
           state(i,j,k,UFS+1)= 1.d0 - exp(-r2)

        enddo
     enddo
  enddo
 end subroutine ca_initdata
