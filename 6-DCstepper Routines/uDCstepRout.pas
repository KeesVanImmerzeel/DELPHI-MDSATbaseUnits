unit uDCstepRout;
  {-Definieert typen TDCStepRout & TDCRoot}

interface
uses
  LargeArrays, ExtParU, USpeedProc, uDCfunc, UAlgRout, UStepRout, xyTable, DUtils;

type
  TDCRoot = Function( var y, dydx, yscal: TLargeRealArray; var xs, htry, hmin, hdid,
                      hnext, eps: double; var EP: TExtParArray; var Direction: TDirection;
                      var DerivsProc: TDerivs; var AlgRout: TAlgRout; 
					  var StepRout: TStepRout;
                      var ModelProfile: PModelProfile; 
					  var nsubstep, nstep, IErr: Integer ): Double;
  {-Functie die, het moment insluit waarop een discontinuiteitsfunctie van teken verandert. 
    Het functie-resultaat bevat het eind van het interval.
    De procedure 'StepRout' wordt gebruikt voor de integratie in het continue domein.
    De discontinuiteit wordt gedetecteerd en ingesloten op basis van 'ModelProfile'.
    ZIE VERDER DE BESCHRIJVING VAN 'TStepRout' IN 'UStepRout'.}

  TDCStepRout = Procedure( var y, dydx, yscal: TLargeRealArray; var xs,
                           htry, hmin, hdid, hnext, eps: Double;
                           var EP: TExtParArray; var Direction: TDirection;
                           var DerivsProc: TDerivs; var AlgRout: TAlgRout;
						   var StepRout: TStepRout; var DCRoot: TDCRoot;
						   var nsubstep, nstep, IErr: Integer );
   {-Stepper-routine with the capability to handle discontinuities. If a discontinuity is
     encountered, TDCStepRout limits hdid to the moment the discontinuity occurs. This is
     done with te root-finding procedure DCRoot.
     This procedure must set the value of the pointer 'ModelProfile' by a call
     to DerivsProc. De pointer 'ModelProfile' is defined in 'DCstepRout.dpr'.
     Er wordt vanuit gegaan dat het modelprofiel voor aanroep van deze routine reeds is
     vastgelegd aan het begin van het tijdsinterval (xs). Dit wordt dus verzorgd in de
     driver-routine (Context=ProfileReset).}

{var
  ModelProfile: PModelProfile;}

Const
  {-Error Codes: -11199..-10200}
  cTooManyClose_In_Iterations           = -11199;
  cNrOfDiscontHasBecomeZeroInsteadOfOne = -11198;
  cRootNotBracketed                     = -11197;
  cNrIterExceededInRootFindingProcedure = -11196;

implementation

end.
