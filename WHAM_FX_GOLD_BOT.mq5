//+------------------------------------------------------------------+
//|                  WHAM-FX GOLD SCALPER                            |
//|                  XAUUSD Expert Advisor for MT5                   |
//|                  Version 1.00                                    |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#property description "WHAM-FX Gold Scalper - Demo testing first"

#include <Trade/Trade.mqh>

CTrade trade;

//--- Trading settings
input bool   EnableTrading       = false;
input double LotSize             = 0.01;
input int    FastEMA             = 9;
input int    SlowEMA             = 21;
input int    RSIPeriod           = 14;
input double BuyRSILevel         = 55.0;
input double SellRSILevel        = 45.0;
input int    ATRPeriod           = 14;
input double StopLossATR         = 2.0;
input double TakeProfitATR       = 3.0;
input int    MaxSpreadPoints     = 100;
input ulong  MagicNumber          = 29102026;

//--- Indicator handles
int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;
int rsiHandle  = INVALID_HANDLE;
int atrHandle  = INVALID_HANDLE;

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Initialize the Expert Advisor                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(FastEMA <= 0 || SlowEMA <= FastEMA ||
      RSIPeriod <= 0 || ATRPeriod <= 0 ||
      LotSize <= 0 || StopLossATR <= 0 ||
      TakeProfitATR <= 0)
   {
      Print("WHAM-FX: Invalid input settings.");
      return INIT_PARAMETERS_INCORRECT;
   }

   fastHandle = iMA(_Symbol, PERIOD_M5, FastEMA, 0,
                    MODE_EMA, PRICE_CLOSE);

   slowHandle = iMA(_Symbol, PERIOD_M5, SlowEMA, 0,
                    MODE_EMA, PRICE_CLOSE);

   rsiHandle = iRSI(_Symbol, PERIOD_M5,
                    RSIPeriod, PRICE_CLOSE);

   atrHandle = iATR(_Symbol, PERIOD_M5, ATRPeriod);

   if(fastHandle == INVALID_HANDLE ||
      slowHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
   {
      Print("WHAM-FX: Failed to initialize indicators.");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFillingBySymbol(_Symbol);

   Print("WHAM-FX initialized on ", _Symbol,
         ". Trading enabled: ", EnableTrading);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Release indicator resources                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(fastHandle != INVALID_HANDLE)
      IndicatorRelease(fastHandle);

   if(slowHandle != INVALID_HANDLE)
      IndicatorRelease(slowHandle);

   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);

   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Detect a new M5 candle                                           |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBar = iTime(_Symbol, PERIOD_M5, 0);

   if(currentBar == 0 || currentBar == lastBarTime)
      return false;

   lastBarTime = currentBar;
   return true;
}

//+------------------------------------------------------------------+
//| Check for an existing WHAM-FX position                           |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) ==
         (long)MagicNumber)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Validate and normalize volume                                    |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double minimum = SymbolInfoDouble(
      _Symbol, SYMBOL_VOLUME_MIN);

   double maximum = SymbolInfoDouble(
      _Symbol, SYMBOL_VOLUME_MAX);

   double step = SymbolInfoDouble(
      _Symbol, SYMBOL_VOLUME_STEP);

   if(step <= 0 || volume < minimum || volume > maximum)
      return 0.0;

   volume = MathFloor(volume / step + 0.0000001) * step;

   int digits = 0;
   double checkStep = step;

   while(digits < 8 &&
         MathAbs(checkStep - MathRound(checkStep)) > 0.0000001)
   {
      checkStep *= 10.0;
      digits++;
   }

   return NormalizeDouble(volume, digits);
}

//+------------------------------------------------------------------+
//| Main trading logic                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!EnableTrading)
      return;

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return;

   if(!IsNewBar())
      return;

   if(BarsCalculated(fastHandle) < SlowEMA + 5 ||
      BarsCalculated(slowHandle) < SlowEMA + 5 ||
      BarsCalculated(rsiHandle) < RSIPeriod + 5 ||
      BarsCalculated(atrHandle) < ATRPeriod + 5)
      return;

   // Read the two most recently closed candles.
   double fast[2], slow[2], rsi[2], atr[2];

   if(CopyBuffer(fastHandle, 0, 1, 2, fast) != 2 ||
      CopyBuffer(slowHandle, 0, 1, 2, slow) != 2 ||
      CopyBuffer(rsiHandle, 0, 1, 2, rsi) != 2 ||
      CopyBuffer(atrHandle, 0, 1, 2, atr) != 2)
   {
     ￼Enter
