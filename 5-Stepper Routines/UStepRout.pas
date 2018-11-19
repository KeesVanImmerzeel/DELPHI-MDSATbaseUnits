unit UStepRout;
  {-Exports type TStepRout}

interface
uses
  LargeArrays, ExtParU, USpeedProc, uDCfunc, UAlgRout, xyTable, DUtils;

type
  TStepRout = Procedure( var y, dydx, yscal: TLargeRealArray; var xs,
                         htry, hmin, hdid, hnext, eps: Double;
                         var EP: TExtParArray; var Direction: TDirection;
                         var DerivsProc: TDerivs; var AlgRout: TAlgRout; 
						 var nsubstep, nstep, IErr: Integer );
  {-Given the dependent variable vector y and their derivatives dydx known at
    the independent variable xs, advance the solution over an interval hdid.

    In stepper routines with adaptive stepsize control, the local truncation error
    is evaluated in order to ensure accuracy and adjust the stepsize.
    Input are the stepsize to be attempted htry (= also the max. value of the
    actually accomplishe stepsize hdid), the required accuracy eps and the
    vector yscal against which the error is scaled. nsubstep is passed to the 
    the algorithme routine and plays no role in the stepper routine.

    In some stepper routines 'nstep' equal increments are used to arrive at xs+hdid.

    On output, y and xs are replaced by their new values at xs+hdid.
    hnext is the estimated next stepsize. In principle, dydx is NOT returned undamaged 
    by the stepper routine.

    If the stepsize becomes smaller then hmin, an error occurres (IErr<>0).
    
    Occasionally the stepper-routine may put the internally used integration step in
    the global variable 'Current_xs' (ref. 'USpeedProc.pas'. }
	
implementation

end.
