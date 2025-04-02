set T ordered;          
set S;                  
set W := {1,2,3};       
set C := {'HVAC', 'WM', 'DW'};  
set F;                 

param eta_ESS_charge{W};        
param ESS_charge_rate{W};       
param ESS_discharge_rate{W};    
param SOC_ESS_initial{W};       
param SOC_ESS_max{W};           
param SOC_ESS_min{W};           

param eta_EV_charge{W};         
param eta_EV_discharge{W};      
param EV_charge_rate{W};        
param EV_discharge_rate{W};     
param SOC_EV_initial{W};        
param SOC_EV_max{W};            
param SOC_EV_min{W};            
param EV_arrival{W};            
param EV_departure{W};          

param P_PV{W,T};                
param InfLoad{W,T};             

param N{W,S,C};                 
param P_consumption{W,C,F};     
param phase_duration{W,C,F};    

param energy_price_buy{T};       
param energy_price_sell{T};      
param deltaT;                   

param T_ref;                 
param T_actual{W,T};         

var P_grid{W,T} >= 0;           
var P_community{W,T} >= 0;      
var ESS_charge{W,T} >= 0;       
var ESS_discharge{W,T} >= 0;    
var EV_charge{W,T} >= 0;        
var EV_discharge{W,T} >= 0;     
var SOC_ESS{W,T} >= 0;          
var SOC_EV{W,T} >= 0;           

var P_sold_PV{W,T} >= 0;        
var P_sold_EV{W,T} >= 0;        
var P_sold_ESS{W,T} >= 0;       

var y_community{T} binary;              
var u_ESS_charge{W,T} binary;           
var u_ESS_discharge{W,T} binary;        
var u_EV_charge{W,T} binary;            
var u_EV_discharge{W,T} binary;         
var x_phase_start{W,T,C,F} binary;      
var x_phase_active{W,T,C,F} binary;     
var x_phase_end{W,T,C,F} binary;        

minimize TotalCost:
  sum{w in W, t in T} (P_grid[w,t] * energy_price_buy[t]/1000 * deltaT)
  - sum{w in W, t in T} (P_sold_ESS[w,t] + P_sold_EV[w,t] + P_sold_PV[w,t]) * energy_price_sell[t]/1000 * deltaT;

subject to EnergyBalance{w in W, t in T, s in S}:
  P_grid[w,t] + P_community[w,t] + ESS_discharge[w,t] + EV_discharge[w,t] + P_PV[w,t]
  >= InfLoad[w,t] + sum{c in C, f in F} (x_phase_active[w,t,c,f] * P_consumption[w,c,f]) 
  + ESS_charge[w,t] + EV_charge[w,t];

subject to ESS_SOC_Update{w in W, t in T}:
  SOC_ESS[w,t] = if t == 1 then SOC_ESS_initial[w]
    else SOC_ESS[w,t-1] + (ESS_charge[w,t] * eta_ESS_charge[w] - ESS_discharge[w,t]/eta_ESS_charge[w]) * deltaT;

subject to ESS_SOC_Limits{w in W, t in T}:
  SOC_ESS_min[w] <= SOC_ESS[w,t] <= SOC_ESS_max[w];

subject to EV_SOC_Update{w in W, t in T: t > 1}:
  SOC_EV[w,t] = if t == EV_arrival[w] then SOC_EV_initial[w]
    else if t > EV_arrival[w] and t <= EV_departure[w] then
      SOC_EV[w,t-1] + (EV_charge[w,t] * eta_EV_charge[w] - EV_discharge[w,t]/eta_EV_discharge[w]) * deltaT
    else SOC_EV[w,t-1];

subject to EV_SOC_Init{w in W}:
  SOC_EV[w,1] = SOC_EV_initial[w];

subject to EV_SOC_Limits{w in W, t in T}:
  if t >= EV_arrival[w] and t <= EV_departure[w] then
    SOC_EV_min[w] <= SOC_EV[w,t] <= SOC_EV_max[w];

subject to PhaseStart{w in W, t in T, c in C, f in F: t > 1}:
   x_phase_start[w,t,c,f] <= 1 - x_phase_active[w,t-1,c,f];

subject to PhaseActivation{w in W, t in T, c in C, f in F}:
  x_phase_active[w,t,c,f] >= x_phase_start[w,t,c,f] - x_phase_end[w,t,c,f];

subject to PhaseDuration{w in W, t in T, c in C, f in F: t + phase_duration[w,c,f] -1 <= card(T)}:
  sum{tau in t..t+phase_duration[w,c,f]-1} x_phase_active[w,tau,c,f] >= phase_duration[w,c,f] * x_phase_start[w,t,c,f];

subject to ESS_ChargeDischarge_Mutex{w in W, t in T}:
  u_ESS_charge[w,t] + u_ESS_discharge[w,t] <= 1;

subject to ESS_Charge_Limit{w in W, t in T}:
  ESS_charge[w,t] <= ESS_charge_rate[w] * u_ESS_charge[w,t];

subject to ESS_Discharge_Limit{w in W, t in T}:
  ESS_discharge[w,t] <= ESS_discharge_rate[w] * u_ESS_discharge[w,t];

subject to EV_ChargeDischarge_Mutex{w in W, t in T}:
  u_EV_charge[w,t] + u_EV_discharge[w,t] <= 1;

subject to EV_Charge_Limit{w in W, t in T}:
  EV_charge[w,t] <= EV_charge_rate[w] * u_EV_charge[w,t];

subject to EV_Discharge_Limit{w in W, t in T}:
  EV_discharge[w,t] <= EV_discharge_rate[w] * u_EV_discharge[w,t];

subject to LocalEnergyBalance{t in T, s in S}:
  sum{w in W} P_community[w,t] = sum{w in W} (P_sold_ESS[w,t] + P_sold_EV[w,t] + P_sold_PV[w,t]);

subject to PVPowerAllocation{w in W, t in T}:
  P_PV[w,t] = P_community[w,t] + P_sold_PV[w,t];
