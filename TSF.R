library(data.table) # For converting data into time series format
library(ggplot2) # To plot various plots
library(fpp2) # For examining seasonality graphically
library(forecast) # For various functions related to Time series
library(stats) # For applying tests like acf, Ljung-Box Tests
library(tseries)# For applying Dickey Fuller test
library(MLmetrics) # For applying various metrics related to ML

data = gas

str(data)
start(data)
end(data)
frequency(data)
cycle(data)

#Reading the data as a time-series object
ts.data = ts(gas, start = c(1956,1), end = c(1995,8), frequency = 12)

summary(ts.data)
str(ts.data)

#the Gas Production values range from 1646 to 66600
#We see that the data spans from January 1956 to August 1995 and it is a monthly time-series data.
#The data follows a time order and there are no missing values
#Periodicity of the dataset is monthly.


ts.plot(ts.data, xlab = "Year", ylab = "Gas Production", main = "Australian Monthly Gas Production")

#The gradual increase in production suggests the presence of trend component
#The stable intra-year fluctuations indidcate the presence of seasonal component in time-series data.
#The data clearly shows that production was stationary with stable seasonal fluctuations from 1956 to 1969. So, the overall series in non-stationary.
#There onwards production has increased greatly showing strong presence of trend component.

boxplot(ts.data ~ cycle(data), xlab = "Months", ylab = "Production", main = "Boxplot of Monthly Gas Production")

#Production appears to be highest in the months of July and August and lowest in December-January

monthplot(ts.data)

#The vertical lines represting monthly production suggest highest production in July and also highest average production in July as represented by the horizontal lines. 

ggseasonplot(ts.data, year.labels = TRUE, year.labels.left = TRUE)

ggseasonplot(ts.data, polar = TRUE) 

#There appears to be a sudden dip in production in March 1993 and a few other instances but the general seasonality suggests highest productoin in July or August
#Production remained nearly constant till 1969 thereafter increased every year.
#The above plots show that Production has seasonal fluctuations along with a trend. Thus there is evidence of multiplicative seasonality.

#Decompose the data

decomp.data.add = decompose(ts.data, type = "additive")
plot(decomp.data.add)

decomp.data.multi = decompose(ts.data, type = "multiplicative")
plot(decomp.data.multi)

#No major changes between the multiplicative and additive models except for the random component.

seasonal.indc = round(t(decomp.data.multi$figure),2)
seasonal.indc

#By observing he seasonal indices we identify the highest production month as July(bearing the highest value of the seasonal component)
#and lowest production month as January having the lowest seasonality component.

stl.data = stl(log(ts.data), s.window = "p")
plot(stl.data)

stl.data.3 = stl(ts.data, s.window = 3)
plot(stl.data.3)

stl.data$time.series[1:12,1]
data.season = exp(stl.data$time.series[1:12,1])
plot(data.season, type="l")

#We observe constant seasonality in the data
#Trend is highly significant as indicated by the small grey bars on the right and increases steadily from 1970 and then again attains normality 1990 onwards

#Deseasonalize the data

deseason.data = exp(stl.data$time.series[,2]) + exp(stl.data$time.series[,3])
ts.plot(deseason.data)
ts.plot(ts.data, deseason.data, col=c("red", "blue"), main="Comparison of Production and Deseasonalized Production")


#Splitiing the time-series data in train and test data

ts.train = window(ts.data, start = c(1956,1), end = c(1985,12), frequency = 12)

ts.test = window(ts.data, start = c(1986,1), frequency = 12)

autoplot(ts.train, series="Train") +
  autolayer(ts.test, series="Test") +
  ggtitle("Gas Production Traning and Test data") +
  xlab("Year") + ylab("Production") +
  guides(colour=guide_legend(title="Forecast"))

#Random Walk with Drift

ts.decomp.train = stl(log10(ts.train), s.window = "p")

ts.train.stl = forecast(ts.decomp.train, method = "rwdrift", h = 120)
plot(ts.train.stl)

vec1 = cbind(log10(ts.test),as.data.frame(forecast(ts.decomp.train, method = "rwdrift", h = 116))[,1])

vec = cbind(log10(ts.test),ts.train.stl$mean)

ts.plot(vec1, col = c("blue", "red"), main = "Australian Gas Production: Actual vs Forecast")

# We notice that the forecasted data matches closely with the actual data from about 1986 to 1988 suggesting that the model can forecast accurately for 2 about years.   

RMSE = round(sqrt(sum(((vec1[,1]-vec1[,2])^2)/length(vec1[,1]))),4)
RMSE

MAPE = round(mean(abs(vec1[,1]-vec1[,2])/vec1[,1]),4)
MAPE

#Box-Ljung test:
#H0: Residuals are Independent
#Ha: Residuals are not Independent

Box.test(ts.train.stl$residuals, type="Ljung-Box")

#Accuracy measures give us a Root Mean Square Error value of 0.1483 and a Mean Absolute Percentage Error value of 0.0252. Also the Ljung-Box test gives us a very small p-value of 0.0008378 whcih signifies that the residuals are not independant.
#This suggests that Random Walk with drift can give us a strong model which can forecast accurately for about 2 years the Australian Gas Production based on the given dataset.



#ARIMA

#Auto Regressive Induced Moving Average(ARIMA) requires a stationary time series so we check the data for stationarity using ADF test.

# Augmented Dicky Fuller Test


#????0: Time series is non-stationary
#????1: Time series is stationary

adf.test(ts.train)

# We check for stationarity after log transfor

ts.train.log = log10(ts.train)

adf.test(ts.train.log)

# We observe that in both the cases the P-value after conducting Augmented Dicky Fuller test is much higher than 5% which leads us to conclude that the series in non-stationary.

acf(ts.train, lag = 116, main = "ACF Time Series")
pacf(ts.train, lag = 116, main = "PACF Time Series")

acf(ts.train.log, lag = 116, main = "ACF Time Series")
pacf(ts.train.log, lag = 116, main = "PACF Time Series")


#We try differencing the data to make the series stationary.

ts.train.df = diff(ts.train)
plot(ts.train.df)

acf(ts.train.df, lag = 116)
pacf(ts.train.df, lag = 116)

adf.test(ts.train.df)

#Autocorrelations are significant upto a very high lag value in the ACF plot. But after differencing the values change and we take q = 0.
#The Partial Autocorrelations seem to suggest that about 1 past observation are significant hence, we take the p value for ARIMA as 1.

arima.train = Arima(ts.train.df,c(1,1,0))
arima.train

hist(arima.train$residuals, col = "beige")

arima.fit = fitted(arima.train)

ts.plot(ts.train.df, arima.fit, col = c("red","blue"))
acf(arima.train$residuals)   


Box.test(arima.train$residuals, type="Ljung-Box")

#The Ljung-Box test gives us a p-value of 60% whcih signifies that the residuals are independant.

autoarima.train = auto.arima(ts.train.log, seasonal = TRUE)
autoarima.train

#According to the auto arima result we should use the ARIMA(1,0,1)(0,1,2)[12] model for this time series data.
#The lower AIC and BIC values indicate that the auto.arima model is better in terms of goodness of fit.

tsf = Arima(ts.train.log, order = c(0,1,1), seasonal = c(0,1,2), method ="ML")
tsf

#By using a seasonal ARIMA model with parameters obtained from auto.arima we get a better model.

Box.test(tsf$residuals, type="Ljung-Box")

#The Ljung-Box test gives us a p-value of over 80% whcih signifies that the residuals are stationary.

ProdForecast = forecast(tsf, h = 116)
plot(ProdForecast)

vec2 = cbind(log10(ts.test),as.data.frame(forecast(tsf, h = 116))[,1])

ts.plot(vec2, col = c("blue", "red"), main = "Australian GAs Production: Actual vsForecast")

RMSE1 = round(sqrt(sum(((vec2[,1]-vec2[,2])^2)/length(vec2[,1]))),4)
RMSE1

MAPE1 = round(mean(abs(vec2[,1]-vec2[,2])/vec2[,1]),4)
MAPE1

#The SARIMA model gives us a Root Mean Square error value of 0.0877 and Mean Absolute Percentage Error value of 0.0145 which suggests that this is a better model than RWDrift.

#We proceed to forecast for the next 12 months using the SARIMA model.

ts.final.arima = Arima(log10(ts.data), order = c(0,1,1), seasonal = c(0,1,2), method = 'ML')
ts.final.arima


ts.final.forecast = forecast(ts.final.arima , h = 12)
plot(ts.final.forecast)
