##Get Phis and Thetas for ARIMA (currently uses top AIC for p and q)
json_file<-get_Phi_Thetas_aic(json_file)

##Forecast

ARIMA_Forecasts<-lapply(2:3,function(x) forecast_arima(json_file[1:20],horizon=x))

##Write forecasts to folder as json
