; Iterate kj with rsfwc with file based communiction

pro kj_iterate, jPFile=jPFile, itStartNo=itStartNo, nIterations=nIterations

	if keyword_set(itStartNo) then itStart=itStartNo else itStart=0
	if keyword_set(nIterations) then nIt=nIterations else nIt=20

	cd, current=runDir
	runIdent = file_baseName(runDir)
	rsfwcCfg = kj_read_rsfwc_cfg('data/rsfwc_input.pro')
	kjCfg = kj_read_cfg('kj.cfg')

	jAmpMax = 50.0
	jAmpStep = 50.0 

	nk = 10 
	jGuessFileList = strArr(nk)

	for it=itStart,itStart+nIt-1 do begin

		for k=0,nk-1 do begin

			print, 'Iteration: ', string(it,format='(i3.3)'),' of ', $
					string(itStart+nIt-1,format='(i3.3)'), ' and sub-it: ', $
					string(k,format='(i3.3)'), ' of ', string(nk-1,format='(i3.3)')

			thisIdent = runIdent+'_'+string(k+1,format='(i3.3)')
			lastIdent = runIdent+'_'+string(k+1-1,format='(i3.3)')

			rsfwcCfg.runIdent = thisIdent 
			rsfwcCfg.jAmp = ((k+1)*jAmpStep)<jAmpMax

			if(k eq 0 and not keyword_set(jPFile) ) then begin
				rsfwcCfg.kjInput=0 
				rsfwcCfg.kj_jP_fileName = ''
			endif else if(k eq 0 and keyword_set(jPFile) ) then begin
				print, 'Continuing withh file ... ', jPFile
				rsfwcCfg.kjInput=1 
				rsfwcCfg.kj_jP_fileName = jPFile
			endif else begin
				rsfwcCfg.kjInput=1
				rsfwcCfg.kj_jP_fileName = 'kj_jP_'+lastIdent+'.nc'
			endelse

			kj_write_rsfwc_cfg, rsfwcCfg, k

			cd, 'data'
			spawn, 'idl -quiet run_rsfwc'
			cd, runDir

			kjCfg.eField_fName = 'data/rsfwc_1d_'+rsfwcCfg.runIdent+'.nc'
			jGuessFileList[k] = 'data/kj_jP_'+kjCfg.runIdent+'.nc'
			kjCfg.runIdent = thisIdent 

			kj_write_kj_cfg, kjCfg, k

			spawn, '~/code/kineticj/bin/kineticj'
			spawn, 'idl -quiet run_kj_plot_current'
			spawn, 'cp output/kj_jP_'+thisIdent+'.nc data/'

		endfor

		; Read the previous n guesses and apply vector extrapolation

		jGuess = !null

		for k=0,nk-1 do begin

			cdfId = ncdf_open(jGuessFileList[k])

				print, jGuessFileList[k]

				ncdf_varget, cdfId, 'r', r 
				ncdf_varget, cdfId, 'r_', r_ 

				ncdf_varget, cdfId, 'jP_r_re', jP_r_re
				ncdf_varget, cdfId, 'jP_r_im', jP_r_im
				ncdf_varget, cdfId, 'jP_p_re', jP_p_re
				ncdf_varget, cdfId, 'jP_p_im', jP_p_im
				ncdf_varget, cdfId, 'jP_z_re', jP_z_re
				ncdf_varget, cdfId, 'jP_z_im', jP_z_im

			ncdf_close, cdfId

			nX = n_elements(r)

			jGuess = [[jGuess],[complex(jP_r_re,jP_r_im)]]

		endfor

		x = jGuess
		_k = n_elements(x[0,*])

		s = kj_mpe(x)
		s_ = complex(spline(r,real_part(s),r_,10.0),spline(r,imaginary(s),r_,10.0))

		s_re = real_part(s)
		s_im = imaginary(s)

		s_re_ = real_part(s_)
		s_im_ = imaginary(s_)

		;p=plot(s,dim=[1200,400],buffer=1,color='b')
		;for i=0,_k-1 do !null=plot(x[*,i],/over)
		;p.save, 'tmpr.eps'

		;p=plot(imaginary(s),dim=[1200,400],buffer=1,color='b')
		;for i=0,_k-1 do !null=plot(imaginary(x[*,i]),/over)
		;p.save, 'tmpi.eps'

		print, 'Writing vector extrapolated jP to file ... ', jGuessFileList[0]
		cdfId = ncdf_open(jGuessFileList[0],/write)

			jP_r_re_id = nCdf_varid(cdfId, 'jP_r_re')
			jP_r_im_id = nCdf_varid(cdfId, 'jP_r_im')
			jP_r_re_id_ = nCdf_varid(cdfId, 'jP_r_re_')
			jP_r_im_id_ = nCdf_varid(cdfId, 'jP_r_im_')
	
			nCdf_varPut, cdfId, jP_r_re_id, s_re
			nCdf_varPut, cdfId, jP_r_im_id, s_im
			nCdf_varPut, cdfId, jP_r_re_id_, s_re_
			nCdf_varPut, cdfId, jP_r_im_id_, s_im_
	
		nCdf_close, cdfId

		pr=plot(s_re,color='b',thick=6,buffer=1, dim=[1200,400],transp=50)
		for k=0,nk-1 do begin
			!null=plot(real_part(jGuess[*,k]),/over,transp=50)
		endfor
		pi=plot(s_im,color='b',thick=6,buffer=1, dim=[1200,400],transp=50)
		for k=0,nk-1 do begin
			!null=plot(imaginary(jGuess[*,k]),/over,transp=50)
		endfor

		pr.save, 'jPr.png'
		pi.save, 'jPi.png'

		jPFile = file_baseName(jGuessFileList[0])

	endfor

	stop

end


