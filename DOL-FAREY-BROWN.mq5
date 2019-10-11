//+------------------------------------------------------------------+
//|                                              DOL-FAREY-BROWN.mq5 |
//|                                               Joscelino Oliveira |
//|                                   https://www.mathematice.mat.br |
//+------------------------------------------------------------------+
#property copyright "Joscelino Oliveira"
#property link      "https://www.mathematice.mat.br"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Bibliotecas Padronizadas do MQL5                                 |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>          //-- classe para negociação
#include <Trade\TerminalInfo.mqh>   //-- Informacoes do Terminal
#include <Trade\AccountInfo.mqh>    //-- Informacoes da conta
#include <Trade\SymbolInfo.mqh>     //-- Informacoes do ativo

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Numerando o Expert                                               |
//+------------------------------------------------------------------+
#define EXPERT_MAGIC 200000055

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Classes a serem utilizadas                                       |
//+------------------------------------------------------------------+
CTerminalInfo terminal;
CTrade trade;
CAccountInfo myaccount;
CSymbolInfo mysymbol;

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  Input de dados pelo Usuario                                     |
//+------------------------------------------------------------------+
input double lote=1.0;       //Numero de contratos
input double stopLoss=5.5;   //Pontos para Stop Loss (Stop Fixo)
input double TakeProfitLong=9.5; //Pontos para Lucro Long(Stop Fixo)
input double TakeProfitShort=9.5; //Pontos para Lucro Short(Stop Fixo/Movel)
input string inicio="09:00"; //Horario de inicio(entradas)
input string termino="16:43"; //Horario de termino(entradas)
input string fechamento="17:39"; //Horario de fechamento(entradas)
input bool usarTrailing=true;//Usar Trailing Stop?
input double TrailingStop=5.5; //Pontos para Stop Loss (Stop Movel)
input double tp_trailing=16.5;//Lucro alvo-fixo (Stop movel)
input double lucroMinimo=6.0;//Lucro minimo para mover Stop Movel
input double passo=6.0;//Passo do Stop Movel em pontos
input ulong desvio=2; //Slippage maximo em pontos
input int max_trades=10; //Numero maximo de trades
input int PeriodoLongo=70;       // Período Média Longa
input int PeriodoCurto=30;       // Período Média Curta
input int PeriodoDPO=10; //Periodo DPO
input int shift=0;

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|   Variaveis globais                                              |
//+------------------------------------------------------------------+
MqlDateTime Time;
MqlDateTime horario_inicio,horario_termino,horario_fechamento,horario_atual;
MqlRates candle[];
double  Point();
datetime TimeLastBar;
int maxTrades=0;
int maxTradesDois=0;
int maxTradesTres=0;
int limite=max_trades/2;
int finalizacao=0;
double resultado_liquido=0;
string broker=AccountInfoString(ACCOUNT_COMPANY);
string subject;
string texto;

//-- PREPARANDO PARA RECEBIMENTO DE DADOS DE INDICADORES

int PCR_Handle;
double PCR_Buffer[];
int FORECAST_Handle;
double FORECAST_Buffer1[];
double FORECAST_Buffer2[];
int T_CYCLICAL_Handle;
double T_CYCLICAL_Buffer[];
int TRINITY_Handle;
double TRINITY_Buffer[];
int VELOCIDADE_Handle;
double VELOCIDADE_Buffer[];
int DPO_Handle;
double DPO_Buffer[];
int handlemedialonga, handlemediacurta; // Manipuladores dos dois indicadores de média móvel
int    MACD_Handle;
double MACD_Buffer[]; 

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  ResetLastError();
  
// Definição do símbolo utilizado para a classe responsável

   if(!mysymbol.Name(_Symbol))
      {
       printf("Ativo Inválido!");
       return INIT_FAILED;
      }
  
//-- INICIANDO O RECEBIMENTO DE DADOS DOS INDICADORES
   
   PCR_Handle=iCustom(_Symbol,_Period,"PCR.ex5",20,80,20);
   ArraySetAsSeries(PCR_Buffer,true);

   T_CYCLICAL_Handle=iCustom(_Symbol,_Period,"Track_Cyclical.ex5",10,MODE_SMA,PRICE_OPEN,0.7,0.5,0.3,-0.3,-0.5,-0.7);
   ArraySetAsSeries(T_CYCLICAL_Buffer,true);
   
   TRINITY_Handle=iCustom(_Symbol,_Period,"trinity-impulse.ex5",5,34,MODE_EMA,PRICE_WEIGHTED,VOLUME_REAL);
   ArraySetAsSeries(TRINITY_Buffer,true);
   
   FORECAST_Handle=iCustom(_Symbol,_Period,"Forecast.ex5",8,PRICE_OPEN,3);
   ArraySetAsSeries(FORECAST_Buffer1,true);
   ArraySetAsSeries(FORECAST_Buffer2,true);
   
   VELOCIDADE_Handle=iCustom(_Symbol,_Period,"average_speed.ex5",3,PRICE_OPEN);
   ArraySetAsSeries(VELOCIDADE_Buffer,true);
   
   DPO_Handle=iCustom(_Symbol,_Period,"dpo.ex5",PeriodoDPO);
   ArraySetAsSeries(DPO_Buffer,true);
   
   MACD_Handle=iMACD(_Symbol,_Period,15,33,11,PRICE_CLOSE);
   ArraySetAsSeries(MACD_Buffer,true);
   
   handlemediacurta = iMA(_Symbol,_Period,PeriodoCurto,shift,MODE_EMA,PRICE_OPEN);
   handlemedialonga = iMA(_Symbol,_Period,PeriodoLongo,shift,MODE_EMA,PRICE_OPEN);
   
   ArraySetAsSeries(candle,true); // Invertendo a indexacao dos candles
   
//-- VERIFICANDO O RECEBIMENTO CORRETO DE DADOS DOS INDICADORES

   if (PCR_Handle == INVALID_HANDLE)
     {
       Print("Erro no indicador PCR, erro: ", GetLastError());
       return(INIT_FAILED);
     }
   if (T_CYCLICAL_Handle== INVALID_HANDLE)
     {
       Print("Erro no indicador TRACK_CYCLICAL, erro: ", GetLastError());
       return(INIT_FAILED);
     }
   if (FORECAST_Handle== INVALID_HANDLE)
     {
       Print("Erro no indicador FORECAST, erro: ", GetLastError());
     }
   if (VELOCIDADE_Handle== INVALID_HANDLE)
     {
       Print("Erro no indicador VELOCIDADE, erro: ", GetLastError());
     }

   if (TRINITY_Handle== INVALID_HANDLE)
     {
       Print("Erro no indicador TRINITY, erro: ", GetLastError());
     }
   
   if(handlemediacurta == INVALID_HANDLE || handlemedialonga == INVALID_HANDLE)
   {
      
      return INIT_FAILED;
   }
   
   if(DPO_Handle == INVALID_HANDLE)
   {
      Print("Erro no indicador DPO, erro: ", GetLastError());
      return INIT_FAILED;
   }
   
   if(MACD_Handle == INVALID_HANDLE)
     {
      Print("Erro no indicador MACD, erro: ", GetLastError());
      return INIT_FAILED;
     }
      
   // Verificação de inconsistências nos parâmetros de entrada
   if(PeriodoLongo <= PeriodoCurto)
   {
      Print("Parâmetros de médias incorretos");
      return INIT_FAILED;
   }
//-- Verificar preenchimento de lotes
/*
   if(lote<5)
     {
      Alert("Volume (volume <5) invalido!!");
      ExpertRemove();
     }
*/
//---
   TimeToStruct(StringToTime(inicio),horario_inicio);         //+-------------------------------------+
   TimeToStruct(StringToTime(termino),horario_termino);       //| Conversão das variaveis para mql    |
   TimeToStruct(StringToTime(fechamento),horario_fechamento); //+-------------------------------------+

                                                              //verificação de erros nas entradas de horario

   if(horario_inicio.hour>horario_termino.hour || (horario_inicio.hour==horario_termino.hour && horario_inicio.min>horario_termino.min))
     {
      printf("Parametos de horarios invalidos!");
      return INIT_FAILED;
     }

   if(horario_termino.hour>horario_fechamento.hour || (horario_termino.hour==horario_fechamento.hour && horario_termino.min>horario_fechamento.min))
     {
      printf("Parametos de horarios invalidos!");
      return INIT_FAILED;
     }
//--     
   RefreshRates();

//--- create timer

   EventSetMillisecondTimer(20);               //-- Eventos de timer recebidos uma vez por milisegundo

//-- PARAMETROS DE PREENCHIMENTO DE ORDENS

   bool preenchimento=IsFillingTypeAllowed(_Symbol,ORDER_FILLING_RETURN);
//---
   if(preenchimento=SYMBOL_FILLING_FOK)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(preenchimento=SYMBOL_FILLING_IOC)
                         trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);

//-- SLIPPAGE MAXIMO EM PONTOS

   trade.SetDeviationInPoints(desvio);

//-- IMPRIME O TAMANHO DO PONTO DO ATIVO CORRENTE

   Print("O tamanho do ponto do ativo: "+_Symbol+" eh: ",_Point);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//-- Zerando a memoria dos indicadores

   IndicatorRelease(PCR_Handle);
   IndicatorRelease(FORECAST_Handle);
   IndicatorRelease(T_CYCLICAL_Handle);
   IndicatorRelease(VELOCIDADE_Handle);
   IndicatorRelease(TRINITY_Handle);
   IndicatorRelease(DPO_Handle);
   IndicatorRelease(MACD_Handle);

//--- destroy timer

   EventKillTimer();

//--- A primeira maneira de obter o código de razão de desinicialização 
   Print(__FUNCTION__,"_Código do motivo de não inicialização = ",reason);
//--- A segunda maneira de obter o código de razão de desinicialização 
   Print(__FUNCTION__,"_UninitReason = ",getUninitReasonText(_UninitReason));

  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//-- BUFFERS DOS INDICADORES

   CopyBuffer(FORECAST_Handle,0,0,5,FORECAST_Buffer1);
   CopyBuffer(FORECAST_Handle,1,0,5,FORECAST_Buffer2);
   CopyBuffer(PCR_Handle,0,0,5,PCR_Buffer);
   CopyBuffer(T_CYCLICAL_Handle,0,0,5,T_CYCLICAL_Buffer);
   CopyBuffer(VELOCIDADE_Handle,0,0,5,VELOCIDADE_Buffer);
   CopyBuffer(TRINITY_Handle,0,0,5,TRINITY_Buffer);
   CopyBuffer(DPO_Handle,0,0,5,DPO_Buffer);
   CopyBuffer(MACD_Handle,0,0,5,MACD_Buffer);
   
//-- ENVIO DE ORDENS

   Trades();

//--RESUMO DAS OPERACOES

   if(HorarioFechamento()==true && finalizacao==0)
     {
      ResumoOperacoes(EXPERT_MAGIC);
      finalizacao=1;
     }
   

//--OUTROS PARAMETROS

   double stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(!RefreshRates()){return;}
/*
   datetime time  = iTime(Symbol(),Period(),shift);
   double   open  = iOpen(Symbol(),Period(),shift);
   double   high  = iHigh(Symbol(),Period(),shift);
   double   low   = iLow(Symbol(),Period(),shift);
   double   close = iClose(NULL,PERIOD_CURRENT,shift);
   long     volume= iVolume(Symbol(),0,shift);
   int      bars  = iBars(NULL,0);

   Comment(Symbol(),",",EnumToString(Period()),"\n",
           "Time: ",TimeTradeServer(),"\n",
           "Open: ",DoubleToString(open,Digits()),"\n",
           "High: ",DoubleToString(high,Digits()),"\n",
           "Low: ",DoubleToString(low,Digits()),"\n",
           "Close: ",DoubleToString(close,Digits()),"\n",
           "Volume: ",IntegerToString(volume),"\n",
           "Bars: ",IntegerToString(bars),"\n",
           "FORECAST:",FORECAST_Buffer1[0],"\n",
           "FORECAST (SIGNAL):",FORECAST_Buffer2[0],"\n"
            );
*/
//-- PRE-CALCULO VOLUMES DE TICKS NAS PONTAS COMPRADORA E VENDEDORA
/*
   MqlTick tick_array[];
   CopyTicks(_Symbol,tick_array,COPY_TICKS_TRADE,0,500);
   ArraySetAsSeries(tick_array,true);
   MqlTick tick=tick_array[0];

   if(( tick.flags&TICK_FLAG_BUY)==TICK_FLAG_BUY) //-- Se for um tick de compra
     {
      sumVolBuy+=(long)tick.volume;
      //--Print("Volume compra = ",sumVolBuy);
     }
   else if(( tick.flags&TICK_FLAG_SELL)==TICK_FLAG_SELL) //-- Se for um tick de venda
     {
      sumVolSell+=(long)tick.volume;
      //--Print("Volume venda = ",sumVolSell);
     }

   ZeroMemory(tick_array);*/
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   
//-- TESTE DE CONEXAO
/*      
   while(checkTrading()==false)
     {
      Alert("Negociacao nao permitida!");
      Print("Conta: ",myaccount.TradeAllowed());
      Print("Expert: ", myaccount.TradeExpert()); 
      Print("Sincronizacao: ",mysymbol.IsSynchronized());
      double ping =  TerminalInfoInteger(TERMINAL_PING_LAST)/1000; //-- Último valor conhecido do ping até ao servidor de negociação em microssegundos
      Print("Last ping: ",ping);
      Sleep(5000);
      }
         
//-- TESTANDO A CONEXAO PRINCIPAL DO TERMINAL COM O SERVIDOR DA CORRETORA  

   if(terminal.IsConnected()==false)
     {
      Print("Terminal nao conectado ao servidor da corretora!");
      SendMail("URGENTE - MT5 Desconectado!!!","Terminal desconectou do servidor da corretora! Verifque URGENTE!");
      RefreshRates();
      double ping =  TerminalInfoInteger(TERMINAL_PING_LAST)/1000; //-- Último valor conhecido do ping até ao servidor de negociação em microssegundos
      Print("Last ping antes da desconexao: ",ping);
      Sleep(10000);
     }
*/
//-- VERIFICANDO SE O SERVIDOR PERMITE NEGOCIACAO

   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      Alert("Negociação automatizada é proibida para a conta ",AccountInfoInteger(ACCOUNT_LOGIN),
            " no lado do servidor de negociação");

//-- Removendo EA do grafico
/*
   if(HorarioFechamento()==true && PositionSelect(_Symbol)==false)
     {
      ExpertRemove();
     }
   */
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| FUNCAO DE TRADES                                                 |
//+------------------------------------------------------------------+
void Trades()
  {
   
//-- PARAMETROS INICIAIS

   ResetLastError();
   CopyRates(_Symbol,_Period,0,5,candle);
   MqlTradeRequest request;
   MqlTradeResult  result;
   MqlTick price;
   SymbolInfoTick(_Symbol,price);
   ResumoOperacoes(EXPERT_MAGIC);
   if(result.retcode==10026)
     {
      Alert("Autotrading desabilitado pelo servidor!!");
     }
//-- VARIAVEIS LOCAIS

   double ask = price.ask;                               //-- Preco atual na ponta compradora
   double bid = price.bid;                               //-- Preco atual na ponta vendedora
   ulong ticket=trade.RequestPosition();
   double sloss_long=SymbolInfoDouble(_Symbol,SYMBOL_BID)-stopLoss;  //-- Stop Loss Posicao Comprada
   double tprofit_long=SymbolInfoDouble(_Symbol,SYMBOL_BID)+TakeProfitLong; //-- Take Profit Posicao Comprada
   double sloss_short=SymbolInfoDouble(_Symbol,SYMBOL_ASK)+stopLoss; //-- Stop Loss Posicao Vendida
   double tprofit_short=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-TakeProfitShort; //-- Take Profit Posicao Vendida
   trade.SetExpertMagicNumber(EXPERT_MAGIC); //-- Setando o numero magico do EA
   double meta=(TakeProfitShort-1.0)*10*lote;
   int resultado_mm = AnaliseMedias();
   
// Rates structure array for last two bars 
   MqlRates mrate[2];                 
   CopyRates(Symbol(), Period(), 0, 2, mrate);

// NEW BAR CHECK.
//---------------
   static double   dBar_Open;     
   static double   dBar_High;
   static double   dBar_Low;
   static double   dBar_Close;
   static long     lBar_Volume;
   static datetime nBar_Time;

// Boolean for new BAR confirmation. 
   bool bStart_NewBar = false;

// Check if the price data has changed tov the previous bar.   
   if(mrate[0].open != dBar_Open || mrate[0].high != dBar_High || mrate[0].low != dBar_Low || mrate[0].close != dBar_Close || mrate[0].tick_volume != lBar_Volume || mrate[0].time != nBar_Time)
         {
         bStart_NewBar = true; // A new BAR has appeared!        

// Update the new BAR data.     
         dBar_Open   = mrate[0].open;      
         dBar_High   = mrate[0].high;
         dBar_Low    = mrate[0].low;
         dBar_Close  = mrate[0].close;                 
         lBar_Volume = mrate[0].tick_volume;
         nBar_Time   = mrate[0].time;
         }

// Check if a new bar has formed.   
   if(bStart_NewBar == true && HorarioEntrada()==true)
         {
         Print(_Symbol+ ": NOVA BARRA!");
         Print("Meta: ",meta);
         Print("Resultado: ",resultado_liquido);
         }
    

//+------------------------------------------------------------------+
//|  ESTRATEGIA DE COMPRA 1                                          |
//+------------------------------------------------------------------+

  if(PositionSelect(_Symbol)==false && HorarioEntrada()==true && bStart_NewBar == true && maxTrades<max_trades &&  maxTradesDois<limite && bid<ask && resultado_liquido<meta)// 
     {
     if(FORECAST_Buffer1[0]>FORECAST_Buffer2[0] && resultado_mm == 1 && TRINITY_Buffer[0]>0 && PCR_Buffer[0]>50 && DPO_Buffer[0]>0 && DPO_Buffer[0]>DPO_Buffer[1])// && VELOCIDADE_Buffer[0]>300)// && (( && PCR_Buffer[1]>PCR_Buffer[2] && PCR_Buffer[0]>40) || )
       {
        trade.Buy(lote,_Symbol,0,sloss_long,tprofit_long,"Ordem de COMPRA!");
            //-- VALIDACAO DE SEGURANCA

            if(trade.ResultRetcode()==10008 || trade.ResultRetcode()==10009)
              {
               Print("Ordem de COMPRA no ativo: "+_Symbol+", enviada e executada com sucesso!");
               maxTrades++;
               maxTradesDois++;
               TradeEmailBuy();
              }
              else
                {
                 Print("Erro ao enviar ordem! Erro #",GetLastError()," - ",trade.ResultRetcodeDescription());
                 return;
                 }
                }
              }
           
//+------------------------------------------------------------------+
//|  ESTRATEGIA DE VENDA 1                                           |
//+------------------------------------------------------------------+

 if(PositionSelect(_Symbol)==false && HorarioEntrada()==true && bStart_NewBar == true && maxTrades<max_trades && maxTradesTres<limite && bid<ask && resultado_liquido<meta)// 
   {
   if(FORECAST_Buffer1[0]<FORECAST_Buffer2[0] && resultado_mm == -1 && TRINITY_Buffer[0]<0 && PCR_Buffer[0]<=20 && DPO_Buffer[0]<0 && DPO_Buffer[0]<DPO_Buffer[1])// && VELOCIDADE_Buffer[0]>300)//  && (PCR_Buffer[0]<PCR_Buffer[1] || PCR_Buffer[0]<20)  )
      {
       trade.Sell(lote,_Symbol,0,sloss_short,tprofit_short,"Ordem de VENDA!");
            //-- VALIDACAO DE SEGURANCA

             if(trade.ResultRetcode()==10008 || trade.ResultRetcode()==10009)
               {
                Print("Ordem de VENDA no ativo: "+_Symbol+", enviada e executada com sucesso!");
                maxTrades++;
                maxTradesTres++;
                TradeEmailSell();
                }
                 else
                  {
                   Print("Erro ao enviar ordem! Erro #",GetLastError()," - ",trade.ResultRetcodeDescription());
                   return;
                  }
                }
              }
              
//-- INSERINDO TRAILING STOP DE PASSO FIXO E LUCRO MINIMO

   if(usarTrailing==true && PositionSelect(_Symbol)==true && TrailingStop>0)
     {
      request.action = TRADE_ACTION_SLTP;
      request.symbol = _Symbol;

      ENUM_POSITION_TYPE posType=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentStop=PositionGetDouble(POSITION_SL);
      double openPrice=PositionGetDouble(POSITION_PRICE_OPEN);

      double minProfit=lucroMinimo;
      double step=passo;
      double trailStop=TrailingStop;

      double trailStopPrice;
      double currentProfit;
      double tp_fixo;

      if(posType==POSITION_TYPE_BUY)
        {
         trailStopPrice=SymbolInfoDouble(_Symbol,SYMBOL_BID)-trailStop;
         currentProfit=SymbolInfoDouble(_Symbol,SYMBOL_BID)-openPrice;
         tp_fixo=openPrice+tp_trailing;

         if(trailStopPrice>=currentStop+step && currentProfit>=minProfit)
           {
            request.sl=trailStopPrice;
            request.tp=tp_fixo;
            bool ok=OrderSend(request,result);
           }
        }

      if(posType==POSITION_TYPE_SELL)
        {
         trailStopPrice=SymbolInfoDouble(_Symbol,SYMBOL_ASK)+trailStop;
         currentProfit=SymbolInfoDouble(_Symbol,SYMBOL_ASK)+openPrice;
         tp_fixo=openPrice-TakeProfitShort;

         if(trailStopPrice<=currentStop-step && currentProfit>=minProfit)
           {
            request.sl=trailStopPrice;
            request.tp=tp_fixo;
            bool ok=OrderSend(request,result);
           }
        }
     }

//-- ENCERRANDO POSICAO DEVIDO AO LIMITE DE HORARIO (apos 17h40)

   if(HorarioFechamento()==true && PositionSelect(_Symbol)==true)
     {

      //-- Fecha a posicao pelo limite de horario

      trade.PositionClose(ticket,-1);

      //--- VALIDACAO DE SEGURANCA

      if(!trade.PositionClose(_Symbol))
        {
         //--- MENSAGEM DE FALHA
         Print("PositionClose() falhou. Return code=",trade.ResultRetcode(),
               ". Codigo de retorno: ",trade.ResultRetcodeDescription());

        }
      else
        {
         Print("PositionClose() executado com sucesso. codigo de retorno=",trade.ResultRetcode(),
               " (",trade.ResultRetcodeDescription(),")");
        }
     }
     
//-- ENVIANDO AVISO DE LUCRO DO DIA
  
  if(maxTrades>0 && PositionSelect(_Symbol)==false && resultado_liquido!=0 && HorarioFechamento()==true && (maxTradesDois>0 || maxTradesTres>0))
    {
     SendMail(_Symbol+" - Negociacoes encerradas!","Resultado bruto do ativo R$: "+DoubleToString(NormalizeDouble(resultado_liquido,2))+" !" );
     maxTradesDois=0;
     maxTradesTres=0;
    }

//-- PARALISANDO ROBO APOS ATINGIR LUCRO
  
  if(PositionSelect(_Symbol)==false && resultado_liquido>=meta && HorarioEntrada()==true)
    {
     SendMail(_Symbol+" - Meta atingida, robo paralisado!","Lucro do dia no ativo R$: "+DoubleToString(NormalizeDouble(resultado_liquido,2))+" !" );
     ExpertRemove();
    }
    
//-- ZERANDO OS VALORES DO PEDIDO E SEU RESULTADO

   ZeroMemory(request);
   ZeroMemory(result);

  }//-- Final da funcao Trades
//+------------------------------------------------------------------+  
//+------------------------------------------------------------------+
//| Funcao para enviar email ao iniciar trade (compra)               |
//+------------------------------------------------------------------+
void TradeEmailBuy()
  {
   subject="Trade (COMPRA) iniciado - EA: FAREY-BROWN - na corretora - "+broker+"!";
   texto="O Trade foi iniciado no ativo: "+_Symbol+" .";
   SendMail(subject,texto);
  }
//+------------------------------------------------------------------+  
//+------------------------------------------------------------------+
//| Funcao para enviar email ao iniciar trade (venda)                |
//+------------------------------------------------------------------+
void TradeEmailSell()
  {
   subject="Trade (VENDA) iniciado - EA: FAREY-BROWN - na corretora - "+broker+"!";
   texto="O Trade foi iniciado no ativo: "+_Symbol+" .";
   SendMail(subject,texto);
  }
//+------------------------------------------------------------------+ 
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(void)
  {
//--- refresh rates
   if(!mysymbol.RefreshRates())
     {
      Print("Falha com dados de preco!");
      return(false);
     }
//--- protection against the return value of "zero"
   if(mysymbol.Ask()==0 || mysymbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|VALIDACAO DOS HORARIOS                                            |
//+------------------------------------------------------------------+

bool HorarioEntrada()
  {
   TimeToStruct(TimeCurrent(),horario_atual);

   if(horario_atual.hour>=horario_inicio.hour && horario_atual.hour<=horario_termino.hour)
     {
      // Hora atual igual a de início
      if(horario_atual.hour==horario_inicio.hour)
         // Se minuto atual maior ou igual ao de início => está no horário de entradas
         if(horario_atual.min>=horario_inicio.min)
            return true;
      // Do contrário não está no horário de entradas
      else
         return false;

      // Hora atual igual a de término
      if(horario_atual.hour==horario_termino.hour)
         // Se minuto atual menor ou igual ao de término => está no horário de entradas
         if(horario_atual.min<=horario_termino.min)
            return true;
      // Do contrário não está no horário de entradas
      else
         return false;

      // Hora atual maior que a de início e menor que a de término
      return true;
     }

// Hora fora do horário de entradas
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HorarioFechamento()
  {
   TimeToStruct(TimeCurrent(),horario_atual);

// Hora dentro do horário de fechamento
   if(horario_atual.hour>=horario_fechamento.hour)
     {
      // Hora atual igual a de fechamento
      if(horario_atual.hour==horario_fechamento.hour)
         // Se minuto atual maior ou igual ao de fechamento => está no horário de fechamento
         if(horario_atual.min>=horario_fechamento.min)
            return true;
      // Do contrário não está no horário de fechamento
      else
         return false;

      // Hora atual maior que a de fechamento
      return true;
     }

// Hora fora do horário de fechamento
   return false;
  }
//+------------------------------------------------------------------+  
//+------------------------------------------------------------------+
//|  Checks if our Expert Advisor can go ahead and perform trading   |
//+------------------------------------------------------------------+
bool checkTrading()
  {
   bool can_trade=false;
// check if terminal is syncronized with server, etc
   if(myaccount.TradeAllowed() && myaccount.TradeExpert() && mysymbol.IsSynchronized())
     {
      // do we have enough bars?
      int mbars=Bars(_Symbol,_Period);
      if(mbars>0)
        {
         can_trade=true;
        }
     }
   return(can_trade);
  }

//+--------------------------------------------------------------------+
//+------------------------------------------------------------------+ 
//| Verifica se um modo de preenchimento específico é permitido      | 
//+------------------------------------------------------------------+ 
bool IsFillingTypeAllowed(string symbol,int fill_type)
  {
//--- Obtém o valor da propriedade que descreve os modos de preenchimento permitidos 
   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//--- Retorna true, se o modo fill_type é permitido 
   return((filling & fill_type)==fill_type);
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+ 
//| OBTENDO MOTIVOS DA DESINICIALIZACAO                              | 
//+------------------------------------------------------------------+ 
string getUninitReasonText(int reasonCode)
  {
   string text="";
//--- 
   switch(reasonCode)
     {
      case REASON_ACCOUNT:
         text="Alterações nas configurações de conta!";break;
      case REASON_CHARTCHANGE:
         text="O período do símbolo ou gráfico foi alterado!";break;
      case REASON_CHARTCLOSE:
         text="O gráfico foi encerrado!";break;
      case REASON_PARAMETERS:
         text="Os parâmetros de entrada foram alterados por um usuário!";break;
      case REASON_RECOMPILE:
         text="O programa "+__FILE__+" foi recompilado!";break;
      case REASON_REMOVE:
         text="O programa "+__FILE__+" foi excluído do gráfico!";break;
      case REASON_TEMPLATE:
         text="Um novo modelo foi aplicado!";break;
      default:text="Outro motivo!";
     }
//--- 
   return text;
  }
//+------------------------------------------------------------------+
//|  RESUMO DAS OPERACOES DO DIA                                     |
//+------------------------------------------------------------------+

void ResumoOperacoes(ulong numero_magico) 
{

//Declaração de Variáveis
   datetime comeco, fim;
   double lucro = 0, perda = 0;
   int contador_trades = 0;
   int contador_ordens = 0;
   double resultado;
   ulong ticket;

//Obtenção do Histórico

   MqlDateTime comeco_struct;
   fim = TimeCurrent(comeco_struct);
   comeco_struct.hour = 0;
   comeco_struct.min = 0;
   comeco_struct.sec = 0;
   comeco = StructToTime(comeco_struct);
   
   HistorySelect(comeco, fim);
   
   //Cálculos
   for(int i=0; i<HistoryDealsTotal(); i++)
   {
      ticket = HistoryDealGetTicket(i);
      long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol && HistoryDealGetInteger(ticket, DEAL_MAGIC) == numero_magico)
         {
            contador_ordens++;
            resultado = HistoryDealGetDouble(ticket, DEAL_PROFIT);

            if(resultado < 0)
            {
               perda += -resultado;
            }
            else
            {
               lucro += resultado;
            }

            if(Entry == DEAL_ENTRY_OUT)
            {
               contador_trades++;
            }
         }
      }
   }

   double fator_lucro;

   if(perda > 0)
   {
      fator_lucro = lucro/perda;
   }
   else
      fator_lucro = -1;

   resultado_liquido = lucro - perda;


   //Exibição
   //Print("RESUMO - Trades:  ", contador_trades, " | Expert: ",EXPERT_MAGIC, " | Ordens: ", contador_ordens, " | Lucro: R$ ", DoubleToString(lucro, 2), " | Perdas: R$ ", DoubleToString(perda, 2), 
   //" | Resultado: R$ ", DoubleToString(resultado_liquido, 2), " | FatorDeLucro: ", DoubleToString(fator_lucro, 2));
}
//+------------------------------------------------------------------+
//| Analise do comportamento das medias                              |
//+------------------------------------------------------------------+
int AnaliseMedias()
{
   // Cópia dos buffers dos indicadores de média móvel com períodos curto e longo
   double MediaCurta[], MediaLonga[];
   ArraySetAsSeries(MediaCurta, true);
   ArraySetAsSeries(MediaLonga, true);
   CopyBuffer(handlemediacurta, 0, 0, 2, MediaCurta);
   CopyBuffer(handlemedialonga, 0, 0, 2, MediaLonga);
   //double testeLong=MediaCurta[0]-MediaLonga[0];
   //double testeShort=MediaLonga[0]-MediaCurta[0];
   
   // Compra em caso de cruzamento da média curta para cima da média longa
   if(MediaCurta[0] > MediaLonga[0])// && testeLong>1)
      return 1;
   
   // Venda em caso de cruzamento da média curta para baixo da média longa
   if(MediaCurta[0] < MediaLonga[0])// && testeShort>1)
      return -1;
      
   return 0;
}