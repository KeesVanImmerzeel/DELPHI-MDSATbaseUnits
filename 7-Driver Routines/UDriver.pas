unit UDriver;
  {-Exports type TDriver and function LoadIntMethod}

interface
uses
  Windows, LargeArrays, ExtParU, uDCfunc, USpeedProc, UAlgRout, UStepRout,
  UDCStepRout, Uerror;

type
  TDriver = Procedure( var ystart: TLargeRealArray; var htry, hmin, eps,
                       x1, x2: Double; var EP: TExtParArray;
                       var DerivsProc: TDerivs; var AlgRout: TAlgRout;
		       var StepRout: TStepRout; var DCRoot: TDCRoot;
                       var DCStepRout: TDCStepRout; var nsubstep, nstep,
                       maxstp, nok, nbad, IErr: Integer );
  {-Given the dependent variable vector ystart known at the independent
    variable x1, integrate from x1-x2 with accuracy eps. 
	
	In driver routines with adaptive stepsize control the stepsize
    to be attempted is 'htry', the required accuracy 'eps'. If the stepsize becomes
    smaller then hmin, an error occurres (IErr<>0). Also an error occurres if
    too many steps are necessary (> maxstp). 'nok' and 'nbas' is the number of good 
    and bad (but retried and fixed) steps taken. In this case, 'nstep' is a dummy 
    variable.

    In driver routines WITHOUT adaptive stepsize control 'nstep' equal increments
    are used to arrive at x2.  In this case, 'maxstp', 'nok' and 'nbad' are dummy
    variables.
	
    The variable 'nsubstep' is just passed on to the algorithme routine (ref.
    'UAlgRout.pas').
	
    On output, ystart is replaced by their new values at x2.

    If (htry > 0) then the 'Direction'-variable (unit 'xyTable') should be set
    to 'FrWrd' in the TStepRout; if (htot < 0) then then the 'Direction'-
    variable should be set to 'FrWrd'. This is necessary for DerivsProc to
    return the correct results if the xDep-tables of the EP-array are
    referenced.}

Function LoadIntMethod( const IAlgRout, IStepRout, IDCRoot, IDCStepRout,
                        IDriver: Word; var AlgRout: TAlgRout;
                        var StepRout: TStepRout; var DCRoot: TDCRoot;
                        var DCStepRout: TDCStepRout; var Driver: TDriver ): Integer;

Procedure UnLoadIntMethod;

Function DCRoutinesAreLoaded( var DCRoot: TDCRoot; var DCStepRout: TDCStepRout;
                              var IErr: Integer ): Boolean;
  {-True als (@DCRoot<>nil) and (@DCStepRout<>nil) }

Const
  {-Error-codes: -599...-500}
  cUnableToLoadAlgRoutDLL = -599;
  cUnableToLocateAlgRoutProc = -598;
  cUnableToLoadStepRoutDLL = -597;
  cUnableToLocateStepRoutProc = -596;
  cUnableToLoadDriverDLL = -595;
  cUnableToLocateDriverProc = -594;
  cTooManySteps = -593;
  cStepSizeTooSmall = -592;
  cUnableToLoadDCRootDLL = -591;
  cUnableToLoadDCRootProc = -590;
  cDCRootProcNotLoaded = -589;
  cUnableToLoadDCStepRoutDLL = -588;
  cUnableToLoadDCStepRoutProc = -587;
  cDCStepRoutProcNotLoaded = -586;

implementation

var DLLAlgRout, DLLStepRout, DLLDCRoot, DLLDCStepRout, DLLDriver: THandle;

Function LoadIntMethod( const IAlgRout, IStepRout, IDCRoot, IDCStepRout,
                        IDriver: Word; var AlgRout: TAlgRout;
                        var StepRout: TStepRout; var DCRoot: TDCRoot;
                        var DCStepRout: TDCStepRout; var Driver: TDriver ): Integer;
begin
  {-Load AlgRout}
  DLLAlgRout := LoadLibrary( PChar( AlgRootDir + 'AlgRout.dll' ) );
  if ( DLLAlgRout = 0 ) then begin
    Result := cUnableToLoadAlgRoutDLL;
    Exit;
  end else begin
    @AlgRout := GetProcAddress( DLLAlgRout, PChar( IAlgRout ) );
    if ( @AlgRout = nil ) then begin
      Result := cUnableToLocateAlgRoutProc; Exit;
    end;
    {FreeLibrary( DLLInstance );}
  end;

  {-Load StepRout}
  DLLStepRout := LoadLibrary( PChar( AlgRootDir+'StepRout.dll' ) );
  if ( DLLStepRout = 0 ) then begin
    Result := cUnableToLoadStepRoutDLL;
    Exit;
  end else begin
    @StepRout := GetProcAddress( DLLStepRout, PChar( IStepRout ) );
    if ( @StepRout = nil ) then begin
      Result := cUnableToLocateStepRoutProc; Exit;
    end;
  end;

  {-Load DCRoot}
  DLLDCRoot := LoadLibrary( PChar( AlgRootDir+'DCRootRout.dll' ) );
  if ( DLLDCRoot = 0 ) then begin
    Result := cUnableToLoadDCRootDLL;
    @DCRoot := nil;
    Exit;
  end else begin
    @DCRoot := GetProcAddress( DLLDCRoot, PChar( IDCRoot ) );
    if ( @DCRoot = nil ) then begin
      Result := cUnableToLoadDCRootProc; Exit;
    end;
  end;

  {-Load DCStepRout}
  DLLDCStepRout := LoadLibrary( PChar( AlgRootDir+'DCStepRout.dll' ) );
  if ( DLLDCStepRout = 0 ) then begin
    Result := cUnableToLoadDCStepRoutDLL;
    @DCStepRout := nil;
    Exit;
  end else begin
    @DCStepRout := GetProcAddress( DLLDCStepRout, PChar( IDCStepRout ) );
    if ( @DCStepRout = nil ) then begin
      Result := cUnableToLoadDCStepRoutProc; Exit;
    end;
  end;

  {-Load Driver}
  DLLDriver := LoadLibrary( PChar( AlgRootDir+'Driver.dll' ) );
  if ( DLLDriver = 0 ) then begin
    Result := cUnableToLoadDriverDLL;
    Exit;
  end else begin
    @Driver := GetProcAddress( DLLDriver, PChar( IDriver ) );
    if ( @Driver = nil ) then begin
      Result := cUnableToLocateDriverProc; Exit;
    end;
  end;

  Result := cNoError;
end;

Procedure UnLoadIntMethod;
begin
  Try
    FreeLibrary( DLLAlgRout );
    FreeLibrary( DLLStepRout );
    FreeLibrary( DLLDCRoot );
    FreeLibrary( DLLDCStepRout );
    FreeLibrary( DLLDriver );
  except
  end;
end;

Function DCRoutinesAreLoaded( var DCRoot: TDCRoot; var DCStepRout: TDCStepRout;
                              var IErr: Integer ): Boolean;
begin
  Result := False;
  if ( @DCRoot = nil ) then
    IErr := cDCRootProcNotLoaded
  else if ( @DCStepRout = nil ) then
    IErr := cDCStepRoutProcNotLoaded
  else begin
    Result := True;
    IErr   := cNoError;
  end;
end;

end.
