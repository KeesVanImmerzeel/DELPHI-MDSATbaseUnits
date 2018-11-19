unit USpeedProc;
{-Exports type "TDerivs"}

interface

Uses
  LargeArrays, ExtParU, xyTable, uDCfunc, Dutils;

Type
  TDerivs = Procedure( var x: Double; var y, dydx: TLargeRealArray;
                       var EP: TExtParArray; var Direction: TDirection;
                       var Context: Tcontext; var aModelProfile: PModelProfile; 
					   var IErr: Integer );
  {-Returns the derivatives dydx at location x, given, x, the function values y
    and the external parameters EP. The value of 'Direction' is used to evaluate
    the result in case of discontinuous external parameters.
    Algorithme, Profiling, Trigger: used by the stepper-routine in case
    discontinuity-functions are being used (nDC > 0). IErr=0 if no error occured
    during the calculation of dydx.
    Occasionally, this procedure is able to supply the integrated value in dydx 
    (Analytic_DerivsProc=true). In that case, the procedure additionally needs 
    the current integration step being used (Current_xs). Set the 
    'Analytic_DerivsProc' to 'True' in the boot-procedure of the Derivs-Proc by
    calling the routine 'SetAnalytic_DerivsProc'.
	
    'Current_xs' is placed on the external parameter array 'EP' by some stepper-
    routines. Make sure you select one of those routines if you are dealing with an
    'Analytic_DerivsProc'. The stepper-routines use the routine 'SetCurrent_xs' to 
    place the current integration step on the external parameter array. The Derivs-Proc 
    uses the function 'Current_xs' to retreive this information.}

Function Current_xs( var EP: TExtParArray ): Double;
Procedure SetCurrent_xs( const ICurrent_xs: Double; var EP: TExtParArray );
Function Analytic_DerivsProc( var EP: TExtParArray ): Boolean;
Procedure SetAnalytic_DerivsProc( const IAnalytic_DerivsProc: Boolean; var EP: TExtParArray );

implementation

Function Current_xs( var EP: TExtParArray ): Double;
begin
  with EP[ cEP0 ].xInDep do
    Result := Items[ 0 ].GetValue( cmpCurrent_xs, 1 );
end;

Procedure SetCurrent_xs( const ICurrent_xs: Double; var EP: TExtParArray );
begin
  with EP[ cEP0 ].xInDep do
    Items[ 0 ].SetValue( cmpCurrent_xs, 1, ICurrent_xs  );
end;

Function Analytic_DerivsProc( var EP: TExtParArray ): Boolean;
begin
  with EP[ cEP0 ].xInDep do
    Result := ( Trunc( Items[ 0 ].GetValue( cmpAnalytic_DerivsProc, 1 ) ) = 1 );
end;

Procedure SetAnalytic_DerivsProc( const IAnalytic_DerivsProc: Boolean; var EP: TExtParArray );
begin
  with EP[ cEP0 ].xInDep do
    if IAnalytic_DerivsProc then 
      Items[ 0 ].SetValue( cmpAnalytic_DerivsProc, 1, 1 )
    else
      Items[ 0 ].SetValue( cmpAnalytic_DerivsProc, 1, 0 )  
end;

end.
