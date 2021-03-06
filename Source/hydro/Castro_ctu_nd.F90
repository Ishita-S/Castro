module ctu_module
  !
  ! advection routines in support of the CTU unsplit advection scheme

  use amrex_constants_module
  use castro_error_module
  use amrex_fort_module, only : rt => amrex_real

  implicit none

contains

#ifdef RADIATION
  subroutine ctu_rad_consup(lo, hi, &
                            update, updt_lo, updt_hi, &
                            Erin, Erin_lo, Erin_hi, &
                            uout, uout_lo, uout_hi, &
                            Erout, Erout_lo, Erout_hi, &
                            radflux1, radflux1_lo, radflux1_hi, &
                            qx, qx_lo, qx_hi, &
                            area1, area1_lo, area1_hi, &
#if AMREX_SPACEDIM >= 2
                            radflux2, radflux2_lo, radflux2_hi, &
                            qy, qy_lo, qy_hi, &
                            area2, area2_lo, area2_hi, &
#endif
#if AMREX_SPACEDIM == 3
                            radflux3, radflux3_lo, radflux3_hi, &
                            qz, qz_lo, qz_hi, &
                            area3, area3_lo, area3_hi, &
#endif
                            nstep_fsp, &
                            vol, vol_lo, vol_hi, &
                            dx, dt) bind(C, name="ctu_rad_consup")

    use meth_params_module, only : difmag, NVAR, URHO, UMX, UMY, UMZ, &
                                   UEDEN, UEINT, UTEMP, NGDNV, NQ, &
                                   fspace_type, comoving, &
                                   GDU, GDV, GDW, GDLAMS, GDERADS, &
                                   GDPRES
    use prob_params_module, only : mom_flux_has_p, center, dg
    use rad_params_module, only : ngroups, nugroup, dlognu
    use radhydro_nd_module, only : advect_in_fspace
    use fluxlimiter_module, only : Edd_factor ! function
    use amrex_constants_module, only : ZERO, ONE, TWO, FOURTH, HALF

    integer, intent(in) ::       lo(3),       hi(3)
    integer, intent(in) ::  updt_lo(3),  updt_hi(3)
    integer, intent(in) :: radflux1_lo(3), radflux1_hi(3)
    integer, intent(in) ::    qx_lo(3),    qx_hi(3)
    integer, intent(in) :: area1_lo(3), area1_hi(3)
#if AMREX_SPACEDIM >= 2
    integer, intent(in) :: radflux2_lo(3), radflux2_hi(3)
    integer, intent(in) :: area2_lo(3), area2_hi(3)
    integer, intent(in) ::    qy_lo(3),    qy_hi(3)
#endif
#if AMREX_SPACEDIM == 3
    integer, intent(in) :: radflux3_lo(3), radflux3_hi(3)
    integer, intent(in) :: area3_lo(3), area3_hi(3)
    integer, intent(in) ::    qz_lo(3),    qz_hi(3)
#endif
    integer, intent(in) ::   vol_lo(3),   vol_hi(3)
    integer, intent(in) ::  uout_lo(3),  uout_hi(3)
    integer, intent(in) :: Erout_lo(3), Erout_hi(3)
    integer, intent(in) :: Erin_lo(3), Erin_hi(3)
    integer, intent(inout) :: nstep_fsp


    real(rt), intent(inout) :: update(updt_lo(1):updt_hi(1),updt_lo(2):updt_hi(2),updt_lo(3):updt_hi(3),NVAR)

    real(rt), intent(in) :: radflux1(radflux1_lo(1):radflux1_hi(1),radflux1_lo(2):radflux1_hi(2),radflux1_lo(3):radflux1_hi(3),0:ngroups-1)
    real(rt), intent(in) :: area1(area1_lo(1):area1_hi(1),area1_lo(2):area1_hi(2),area1_lo(3):area1_hi(3))
    real(rt), intent(in) ::    qx(qx_lo(1):qx_hi(1),qx_lo(2):qx_hi(2),qx_lo(3):qx_hi(3),NGDNV)

#if AMREX_SPACEDIM >= 2
    real(rt), intent(in) :: radflux2(radflux2_lo(1):radflux2_hi(1),radflux2_lo(2):radflux2_hi(2),radflux2_lo(3):radflux2_hi(3),0:ngroups-1)
    real(rt), intent(in) :: area2(area2_lo(1):area2_hi(1),area2_lo(2):area2_hi(2),area2_lo(3):area2_hi(3))
    real(rt), intent(in) ::    qy(qy_lo(1):qy_hi(1),qy_lo(2):qy_hi(2),qy_lo(3):qy_hi(3),NGDNV)
#endif

#if AMREX_SPACEDIM == 3
    real(rt), intent(in) :: radflux3(radflux3_lo(1):radflux3_hi(1),radflux3_lo(2):radflux3_hi(2),radflux3_lo(3):radflux3_hi(3),0:ngroups-1)
    real(rt), intent(in) :: area3(area3_lo(1):area3_hi(1),area3_lo(2):area3_hi(2),area3_lo(3):area3_hi(3))
    real(rt), intent(in) ::    qz(qz_lo(1):qz_hi(1),qz_lo(2):qz_hi(2),qz_lo(3):qz_hi(3),NGDNV)
#endif
    real(rt), intent(in) :: vol(vol_lo(1):vol_hi(1),vol_lo(2):vol_hi(2),vol_lo(3):vol_hi(3))
    real(rt), intent(in) :: dx(3)
    real(rt), intent(in), value :: dt

    real(rt), intent(in) :: Erin(Erin_lo(1):Erin_hi(1),Erin_lo(2):Erin_hi(2),Erin_lo(3):Erin_hi(3),0:ngroups-1)
    real(rt), intent(inout) :: uout(uout_lo(1):uout_hi(1),uout_lo(2):uout_hi(2),uout_lo(3):uout_hi(3),NVAR)
    real(rt), intent(inout) :: Erout(Erout_lo(1):Erout_hi(1),Erout_lo(2):Erout_hi(2),Erout_lo(3):Erout_hi(3),0:ngroups-1)

    integer :: i, j, g, k, n
    integer :: domlo(3), domhi(3)
    real(rt) :: volInv

    real(rt), dimension(0:ngroups-1) :: Erscale
    real(rt), dimension(0:ngroups-1) :: ustar, af
    real(rt) :: Eddf, Eddfxm, Eddfxp, Eddfym, Eddfyp, Eddfzm, Eddfzp
    real(rt) :: f1, f2, f1xm, f1xp, f1ym, f1yp, f1zm, f1zp
    real(rt) :: Gf1E(3)
    real(rt) :: ux, uy, uz, divu, lamc, Egdc
    real(rt) :: dudx(3), dudy(3), dudz(3), nhat(3), GnDotu(3), nnColonDotGu
    real(rt) :: dprdx, dprdy, dprdz, ek1, ek2, dek, dpdx
    real(rt) :: urho_new
    real(rt) :: umx_new1, umy_new1, umz_new1
    real(rt) :: umx_new2, umy_new2, umz_new2

    !$gpu

    if (ngroups .gt. 1) then
       if (fspace_type .eq. 1) then
          Erscale = dlognu
       else
          Erscale = nugroup*dlognu
       end if
    end if


    ! radiation energy update.  For the moment, we actually update things
    ! fully here, instead of creating a source term for the update
    do g = 0, ngroups-1
       do k = lo(3),hi(3)
          do j = lo(2),hi(2)
             do i = lo(1),hi(1)
                Erout(i,j,k,g) = Erin(i,j,k,g) + dt * &
                     ( radflux1(i,j,k,g) * area1(i,j,k) - radflux1(i+1,j,k,g) * area1(i+1,j,k) &
#if AMREX_SPACEDIM >= 2
                     + radflux2(i,j,k,g) * area2(i,j,k) - radflux2(i,j+1,k,g) * area2(i,j+1,k) &
#endif
#if AMREX_SPACEDIM == 3
                     + radflux3(i,j,k,g) * area3(i,j,k) - radflux3(i,j,k+1,g) * area3(i,j,k+1) &
#endif
                     ) / vol(i,j,k)
             enddo
          enddo
       enddo
    enddo

    ! Add gradp term to momentum equation -- only for axisymmetry coords
    ! (and only for the radial flux);  also add the radiation pressure gradient
    ! to the momentum for all directions

    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)

             ! pgdnv from the Riemann solver is only the gas contribution,
             ! not the radiation contribution.  Note that we've already included
             ! the gas pressure in the momentum flux for all Cartesian coordinate
             ! directions
             if (.not. mom_flux_has_p(1)%comp(UMX)) then
                dpdx = ( qx(i+1,j,k,GDPRES) - qx(i,j,k,GDPRES))/ dx(1)
                update(i,j,k,UMX) = update(i,j,k,UMX) - dpdx
             endif

             ! radiation contribution -- this is sum{lambda E_r}
             dprdx = ZERO
             dprdy = ZERO
             dprdz = ZERO

             do g = 0, ngroups-1
#if AMREX_SPACEDIM == 1
                lamc = HALF*(qx(i,j,k,GDLAMS+g) + qx(i+1,j,k,GDLAMS+g))
#endif
#if AMREX_SPACEDIM == 2
                lamc = FOURTH*(qx(i,j,k,GDLAMS+g) + qx(i+1,j,k,GDLAMS+g) + &
                     qy(i,j,k,GDLAMS+g) + qy(i,j+1,k,GDLAMS+g))
#endif
#if AMREX_SPACEDIM == 3
                lamc = (qx(i,j,k,GDLAMS+g) + qx(i+1,j,k,GDLAMS+g) + &
                     qy(i,j,k,GDLAMS+g) + qy(i,j+1,k,GDLAMS+g) + &
                     qz(i,j,k,GDLAMS+g) + qz(i,j,k+1,GDLAMS+g) ) / 6.e0_rt
#endif

                dprdx = dprdx + lamc*(qx(i+1,j,k,GDERADS+g) - qx(i,j,k,GDERADS+g))/dx(1)
#if AMREX_SPACEDIM >= 2
                dprdy = dprdy + lamc*(qy(i,j+1,k,GDERADS+g) - qy(i,j,k,GDERADS+g))/dx(2)
#endif
#if AMREX_SPACEDIM == 3
                dprdz = dprdz + lamc*(qz(i,j,k+1,GDERADS+g) - qz(i,j,k,GDERADS+g))/dx(3)
#endif
             end do

             ! we now want to compute the change in the kinetic energy -- we
             ! base this off of uout, since that has the source terms in it.
             ! But note that this does not have the fluxes (since we are
             ! using update)

             ! note, we need to include the Z component here too (even
             ! for 1- and 2-d), since rotation might be in play

             urho_new = uout(i,j,k,URHO) + dt * update(i,j,k,URHO)

             ! this update includes the hydro fluxes and grad{p} from hydro
             umx_new1 = uout(i,j,k,UMX) + dt * update(i,j,k,UMX)
             umy_new1 = uout(i,j,k,UMY) + dt * update(i,j,k,UMY)
             umz_new1 = uout(i,j,k,UMZ) + dt * update(i,j,k,UMZ)

             ek1 = (umx_new1**2 + umy_new1**2 + umz_new1**2) / (TWO*urho_new)

             ! now add the radiation pressure gradient
             update(i,j,k,UMX) = update(i,j,k,UMX) - dprdx
             update(i,j,k,UMY) = update(i,j,k,UMY) - dprdy
             update(i,j,k,UMZ) = update(i,j,k,UMZ) - dprdz

             umx_new2 = umx_new1 - dt * dprdx
             umy_new2 = umy_new1 - dt * dprdy
             umz_new2 = umz_new1 - dt * dprdz

             ek2 = (umx_new2**2 + umy_new2**2 + umz_new2**2) / (TWO*urho_new)

             dek = ek2 - ek1

             ! the update is a source / dt, so scale accordingly
             update(i,j,k,UEDEN) = update(i,j,k,UEDEN) + dek/dt

             if (.not. comoving) then ! mixed-frame (single group only)
                Erout(i,j,k,0) = Erout(i,j,k,0) - dek
             end if

          end do
       end do
    end do

    ! Add radiation source terms to rho*u, rhoE, and Er
    if (comoving) then
       do k = lo(3), hi(3)
          do j = lo(2), hi(2)
             do i = lo(1), hi(1)

                ux = HALF*(qx(i,j,k,GDU) + qx(i+1,j,k,GDU))
#if AMREX_SPACEDIM >= 2
                uy = HALF*(qy(i,j,k,GDV) + qy(i,j+dg(2),k,GDV))
#endif
#if AMREX_SPACEDIM == 3
                uz = HALF*(qz(i,j,k,GDW) + qz(i,j,k+dg(3),GDW))
#endif

                dudx(:) = ZERO
                dudy(:) = ZERO
                dudz(:) = ZERO

                dudx(1) = (qx(i+1,j,k,GDU) - qx(i,j,k,GDU))/dx(1)
                dudx(2) = (qx(i+1,j,k,GDV) - qx(i,j,k,GDV))/dx(1)
                dudx(3) = (qx(i+1,j,k,GDW) - qx(i,j,k,GDW))/dx(1)

#if AMREX_SPACEDIM >= 2
                dudy(1) = (qy(i,j+1,k,GDU) - qy(i,j,k,GDU))/dx(2)
                dudy(2) = (qy(i,j+1,k,GDV) - qy(i,j,k,GDV))/dx(2)
                dudy(3) = (qy(i,j+1,k,GDW) - qy(i,j,k,GDW))/dx(2)
#endif

#if AMREX_SPACEDIM == 3
                dudz(1) = (qz(i,j,k+1,GDU) - qz(i,j,k,GDU))/dx(3)
                dudz(2) = (qz(i,j,k+1,GDV) - qz(i,j,k,GDV))/dx(3)
                dudz(3) = (qz(i,j,k+1,GDW) - qz(i,j,k,GDW))/dx(3)
#endif

                divu = dudx(1) + dudy(2) + dudz(3)

                ! Note that for single group, fspace_type is always 1
                do g=0, ngroups-1

                   nhat(:) = ZERO

                   nhat(1) = (qx(i+1,j,k,GDERADS+g) - qx(i,j,k,GDERADS+g))/dx(1)
#if AMREX_SPACEDIM >= 2
                   nhat(2) = (qy(i,j+1,k,GDERADS+g) - qy(i,j,k,GDERADS+g))/dx(2)
#endif
#if AMREX_SPACEDIM == 3
                   nhat(3) = (qz(i,j,k+1,GDERADS+g) - qz(i,j,k,GDERADS+g))/dx(3)
#endif

                   GnDotu(1) = dot_product(nhat, dudx)
                   GnDotu(2) = dot_product(nhat, dudy)
                   GnDotu(3) = dot_product(nhat, dudz)

                   nnColonDotGu = dot_product(nhat, GnDotu) / (dot_product(nhat,nhat)+1.e-50_rt)

#if AMREX_SPACEDIM == 1
                   lamc = HALF*(qx(i,j,k,GDLAMS+g) + qx(i+1,j,k,GDLAMS+g))
#endif
#if AMREX_SPACEDIM == 2
                   lamc = 0.25e0_rt*(qx(i,j,k,GDLAMS+g) + qx(i+1,j,k,GDLAMS+g) + &
                        qy(i,j,k,GDLAMS+g) + qy(i,j+1,k,GDLAMS+g))
#endif
#if AMREX_SPACEDIM == 3
                   lamc = (qx(i,j,k,GDLAMS+g) + qx(i+1,j,k,GDLAMS+g) + &
                        qy(i,j,k,GDLAMS+g) + qy(i,j+1,k,GDLAMS+g) + &
                        qz(i,j,k,GDLAMS+g) + qz(i,j,k+1,GDLAMS+g) ) / 6.e0_rt
#endif

                   Eddf = Edd_factor(lamc)
                   f1 = (ONE-Eddf)*HALF
                   f2 = (3.e0_rt*Eddf-ONE)*HALF
                   af(g) = -(f1*divu + f2*nnColonDotGu)

                   if (fspace_type .eq. 1) then
                      Eddfxp = Edd_factor(qx(i+1,j  ,k  ,GDLAMS+g))
                      Eddfxm = Edd_factor(qx(i  ,j  ,k  ,GDLAMS+g))
#if AMREX_SPACEDIM >= 2
                      Eddfyp = Edd_factor(qy(i  ,j+1,k  ,GDLAMS+g))
                      Eddfym = Edd_factor(qy(i  ,j  ,k  ,GDLAMS+g))
#endif
#if AMREX_SPACEDIM == 3
                      Eddfzp = Edd_factor(qz(i  ,j  ,k+1,GDLAMS+g))
                      Eddfzm = Edd_factor(qz(i  ,j  ,k  ,GDLAMS+g))
#endif

                      f1xp = HALF*(ONE-Eddfxp)
                      f1xm = HALF*(ONE-Eddfxm)
#if AMREX_SPACEDIM >= 2
                      f1yp = HALF*(ONE-Eddfyp)
                      f1ym = HALF*(ONE-Eddfym)
#endif
#if AMREX_SPACEDIM == 3
                      f1zp = HALF*(ONE-Eddfzp)
                      f1zm = HALF*(ONE-Eddfzm)
#endif

                      Gf1E(1) = (f1xp*qx(i+1,j,k,GDERADS+g) - f1xm*qx(i,j,k,GDERADS+g)) / dx(1)
#if AMREX_SPACEDIM >= 2
                      Gf1E(2) = (f1yp*qy(i,j+1,k,GDERADS+g) - f1ym*qy(i,j,k,GDERADS+g)) / dx(2)
#endif
#if AMREX_SPACEDIM == 3
                      Gf1E(3) = (f1zp*qz(i,j,k+1,GDERADS+g) - f1zm*qz(i,j,k,GDERADS+g)) / dx(3)
#endif


#if AMREX_SPACEDIM == 1
                      Egdc = HALF*(qx(i,j,k,GDERADS+g) + qx(i+1,j,k,GDERADS+g))
                      Erout(i,j,k,g) = Erout(i,j,k,g) + dt*ux*Gf1E(1) &
                           - dt*f2*Egdc*nnColonDotGu
#endif
#if AMREX_SPACEDIM == 2
                      Egdc = 0.25e0_rt*(qx(i,j,k,GDERADS+g) + qx(i+1,j,k,GDERADS+g) + &
                           qy(i,j,k,GDERADS+g) + qy(i,j+1,k,GDERADS+g))
                      Erout(i,j,k,g) = Erout(i,j,k,g) + dt*(ux*Gf1E(1)+uy*Gf1E(2)) &
                           - dt*f2*Egdc*nnColonDotGu
#endif
#if AMREX_SPACEDIM == 3
                      Egdc = (qx(i,j,k,GDERADS+g) + qx(i+1,j,k,GDERADS+g) &
                           +  qy(i,j,k,GDERADS+g) + qy(i,j+1,k,GDERADS+g) &
                           +  qz(i,j,k,GDERADS+g) + qz(i,j,k+1,GDERADS+g) ) / 6.e0_rt
                      Erout(i,j,k,g) = Erout(i,j,k,g) + dt*(ux*Gf1E(1)+uy*Gf1E(2)+uz*Gf1E(3)) &
                           - dt*f2*Egdc*nnColonDotGu
#endif

                   end if

                end do

                if (ngroups.gt.1) then
                   ustar = Erout(i,j,k,:) / Erscale
                   call advect_in_fspace(ustar, af, dt, nstep_fsp)
                   Erout(i,j,k,:) = ustar * Erscale
                end if
             enddo
          enddo
       enddo
    endif

  end subroutine ctu_rad_consup
#endif

end module ctu_module
