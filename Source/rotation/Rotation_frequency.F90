module rotation_frequency_module

  use castro_error_module
  use amrex_fort_module, only : rt => amrex_real
  implicit none

contains

  subroutine get_omega(omega) bind(C, name="get_omega")

    use prob_params_module, only: coord_type
    use meth_params_module, only: rot_period, rot_axis
    use amrex_constants_module, only: ZERO, TWO, M_PI
    use amrex_fort_module, only : rt => amrex_real

    implicit none

    real(rt), intent(inout) :: omega(3)

    ! If rot_period is less than zero, that means rotation is disabled, and so we should effectively
    ! shut off the source term by setting omega = 0. Note that by default rot_axis == 3 for Cartesian
    ! coordinates and rot_axis == 2 for cylindrical coordinates.

    !$gpu

    omega(:) = ZERO

    if (coord_type == 0 .or. coord_type == 1) then

       if (rot_period > ZERO) then

          omega(rot_axis) = TWO * M_PI / rot_period

       endif

    else
#ifndef AMREX_USE_GPU
       call castro_error("Error:: rotation_nd.f90 :: invalid coord_type")
#endif
    endif

  end subroutine get_omega

  subroutine set_rot_period(period) bind(C, name='set_rot_period')

    use meth_params_module, only: rot_period

    implicit none

    real(rt), intent(in) :: period

    rot_period = period

  end subroutine set_rot_period
  
end module rotation_frequency_module
