source("helpers.R")

# Define server logic required to draw a histogram
shinyServer(function(input, output, session) {

# Data Exploration
        
        # Create W/L/D Plot
        output$posChart <- renderPlotly({
            
            # Get Filtered Data
            releg2 <- releg2 %>% filter(Season == input$Season)
        
            #Create Plot
            finalChart <- ggplot(releg2, aes(x = Team, label = `Final Ranking`)) +
                geom_col(aes(y = Amount, fill = Games),position = "dodge") +
                theme(axis.text.x = element_text(angle = 45)) +
                scale_y_continuous(breaks = c(5, 10, 15, 20, 25, 30)) +
                scale_fill_brewer(palette="Dark2") +
                labs(title = paste0("Wins, Loses, and Draws for the ", input$Season, " Season"), 
                     x = "Teams", y = "Number of Wins, Loses, and Draws")
        
            ggplotly(finalChart)
        })
        
        # Output from Champion Check box
        output$info <- renderText({
            # Get filtered Data
            releg3 <- releg2 %>% filter(Season == input$Season, `Final Ranking` == 1)
        
            #Champion Text
            if(input$champion)
            paste("The Champion of the", input$Season, "Premier League Season is ",
                  releg3$Team[1], delim = " ")
        })
    
        # Output from Relegation Check box
        output$rele <- renderText({
                
            # Get filtered Data
            releg4 <- releg2 %>% filter(Season == input$Season, `Relegated - Post` == "Yes")
            
            # Relegation Text
            if(input$relegated)
            paste("The teams that will be relegated are", releg4$Team[1], ",", releg4$Team[2], 
                  ", and", releg4$Team[3], delim = " ")
        })

        # Output for Table with Final Rankings
        output$table <- renderTable({
            # Get filtered Data
            releg5 <- releg %>% filter(Season == input$Season) %>% 
                select(`Final Ranking`, Team, Wins, Loses, Draws)
            
            # Table Output for Each Season
            releg5$`Final Ranking` <- as.integer(releg5$`Final Ranking`)
            releg5$Wins <- as.integer(releg5$Wins)
            releg5$Loses <- as.integer(releg5$Loses)
            releg5$Draws <- as.integer(releg5$Draws)
            releg5 <- unique(releg5)
            releg5
        })
        
# k Means Clustering
    
        # Create Distance Graph
        output$dist <- renderPlot({
        
            # Get Filtered Data
            releg4 <- releg4 %>% filter(Season == input$year) %>% 
                select(Club, `Final Ranking`, Wins, Draws, Loses, `Goals For`, `Goals Against`)
        
            # Compute Distance Matrix
            releg5 <- releg4 %>% remove_rownames() %>% column_to_rownames(var = unique("Club"))
            releg5 <- scale(releg5)
            distance <- get_dist(releg5)
        
            # Visualize Distance Matrix
            dist <- fviz_dist(distance, gradient = list(low = "#00AFBB", mid = "white", high = "#FC4E07")) +
                        guides(fill = "none")
            dist
        })
        
        # Create k Clusters
        output$means <- renderPlot({
            
            # Get Filtered Data
            releg4 <- releg4 %>% filter(Season == input$year) %>% 
                select(Club, `Final Ranking`, Wins, Draws, Loses, `Goals For`, `Goals Against`)
            releg5 <- releg4 %>% remove_rownames() %>% column_to_rownames(var = unique("Club"))
            releg5 <- scale(releg5)
            
            # Set Clusters
            k2 <- kmeans(releg5, centers = input$cluster, nstart = 25)
            
            # Graph of Clusters
            means <- fviz_cluster(k2, data = releg5) +
                scale_x_continuous(limits = c(-5, 5)) +
                scale_y_continuous(limits = c(-3,3)) + 
                ggtitle(paste("k = ", input$cluster)) +
                theme(legend.position="none")
            means
        })
        
        # k Centers for each cluster
        output$center <- renderTable({
            
            # Get Filtered Data
            releg4 <- releg4 %>% filter(Season == input$year) %>% 
                select(Club, `Final Ranking`, Wins, Draws, Loses, `Goals For`, `Goals Against`)
            releg5 <- releg4 %>% remove_rownames() %>% column_to_rownames(var = unique("Club"))
            releg5 <- scale(releg5)
            
            # Set Clusters
            k2 <- kmeans(releg5, centers = input$cluster, nstart = 25)
            
            # Output
            cent <- k2$centers
            cent
        }, rownames = TRUE)
        
# k Nearest Neighbors
        
        # Make tables for Prediction
        output$knnTable <- renderTable({
            
            ## Get Data
            knnPred <- knn(trainMat, testMat, trainY, k = input$knn)
            
            ## Prediction Table
            tbl <- table(knnPred, testKnn$relegated_post)
            tbl <- data.frame(tbl[,1:2])
            tbl <- tbl %>% rename(Predicted = knnPred, Actual = Var2, Frequency = Freq)
            tbl
        })
        
        # Accuracy and Misclassification Table
        output$knnAcc <- renderTable({
            
            ## Get Data
            knnPred <- knn(trainMat, testMat, trainY, k = input$knn)
            
            modelMatrix <- matrix(c(paste0(round(mean(knnPred == testKnn$relegated_post)*100, 2), "%"), 
                                    paste0(round(mean(knnPred != testKnn$relegated_post)*100, 2), "%")),
                                  ncol = 2, nrow = 1,
                                  dimnames = list(c("k-Nearest Neighbors"), 
                                                  c("Accuracy", "Misclassification Rate")))
            modelMatrix
        },  rownames = TRUE)
        
        # Predict Relegation
        output$relegated <- renderText({
           
             ## Set up Predictions for K = 9
            set.seed(1234)
        
            trctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 1)
        
            knnFit <- train(relegated_post ~ ., data = trainKnn, 
                            method = "knn",
                            trControl = trctrl, 
                            tuneLength = 3)
        
            ## Test out predictions
            predKnn <- predict(knnFit, newdata = data.frame(wins = input$wins, loses = input$loses,
                                                            draws = input$draws, goal_difference = input$gd))
            relegated <- paste("Team Relegated:",ifelse(predKnn == "No", "No", "Yes"), sep = " ")
            relegated
        })
            
        # Create kNN Plot
        output$knnPlot <- renderPlotly({
            
            #Predict number
            knnPred <- knn(trainMat, testMat, trainY, k = input$knn)
            
            # Create a dataframe to simplify charting
            plot.df <-  data.frame(testKnn, predicted = knnPred)
            
            # First use Convex hull to determine boundary points of each cluster
            
            plot.df1 <-  data.frame(x = plot.df$wins, 
                                    y = plot.df$loses, 
                                    predicted = plot.df$predicted)
            
            find_hull <-  function(df) df[chull(df$x, df$y), ]
            boundary <-  plyr::ddply(plot.df1, .variables = "predicted", .fun = find_hull)
            
            # Actual Plot
            knnPlot <- ggplot(plot.df, aes(wins, loses, color = predicted, fill = predicted)) + 
                geom_polygon(data = boundary, aes(x,y), alpha = 0.5) +
                geom_point(size = 3) +
                labs(x = "Wins", y = "Loses")
            
            ggplotly(knnPlot)
        })
        
# Random Forest
        
        # Gini index using MathJax
        output$gini <- renderUI({
            withMathJax(helpText("The Gini Index is defined by $$G = \\sum_{k=1}^{K} \\hat p_{mk} (1 - \\hat p_{mk})$$"))
        })
        
        # Mean Decrease Gini Plot
        output$mda <- renderPlot({
            
            # Set up Predictors
            if(input$preds == 13){
                colPreds <- c("Matchday", "HomeTeam", "AwayTeam", "HS", 
                              "AS", "HST", "AST", "HF", "AF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 12){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", "HST", "AST",
                              "HF", "AF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 11){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", "HST", 
                              "AST", "HF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 10){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", 
                              "HST", "AST", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 9){
                colPreds <- c("AwayTeam", "HS", "AS", "HST", "AST", "HC", 
                              "AC", "HR", "AR")
            }
            else if(input$preds == 8){
                colPreds <- c("AwayTeam", "HS", "AS", "HST", "AST", "AC", "HR", "AR")
            }
            else if(input$preds == 7){
                colPreds <- c("HS", "AS", "HST", "AST", "AC", "HR", "AR")
            }
            else if(input$preds == 6){
                colPreds <- c("HS", "AS", "HST", "AST", "HR", "AR")
            }
            else if(input$preds == 5){
                colPreds <- c("HS", "AS", "HST", "AST", "HR")
            }
            else if(input$preds == 4){
                colPreds <- c("HS", "AS", "HST", "AST")
            }
            else if(input$preds == 3){
                colPreds <- c("HS", "HST", "AST")
            }
            
            #Train/Test data - 2013-2018 Seasons Train, 2018-2019 Season Test
            xTrain <- data2[1:1900, colPreds]
            xTest <- data2[1901:2280, colPreds]
            
            yTrain <- as.factor(data2[1:1900,]$RES)
            yTest <- as.factor(data2[1901:2280,]$RES)
            
            set.seed(1234)
            
            # Checking Mean Decrease Gini
            model <- randomForest(xTrain, yTrain,
                                  mtry = 2,
                                  ntree = 500,
                                  strata = yTrain, 
                                  importance = TRUE)
            
            # Importance of Predictors
            imp <- as_tibble(importance(model, type = 2))
            imp <- cbind(colPreds, imp)
            imp <- imp %>% rename(Predictors = colPreds) %>% arrange(desc(MeanDecreaseGini))
            
            # Graph Predictors by Importance
            mda <- ggplot(imp, aes(x = reorder(Predictors, MeanDecreaseGini), y = MeanDecreaseGini)) +
                geom_bar(fill = "darkgreen", stat = "identity") +
                coord_flip() +
                labs(title = "Random Forests - Rank by Importance", 
                     x = "Predictors", y = "Mean Decrease in Gini")
            mda
        })
        
        # Random Forest Graph
        output$finModel <- renderPlot({
            
            withProgress(message = 'Making plot',{
                
            #Train/Test data - 2013-2018 Seasons Train, 2018-2019 Season Test
            if(input$preds == 13){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, Matchday, HomeTeam, AwayTeam, HS, AS, HST, AST, HF, AF, HC, AC, HR, AR)
            }
            else if(input$preds == 12){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, HomeTeam, AwayTeam, HS, AS, HST, AST, HF, AF, HC, AC, HR, AR)
            }
            else if(input$preds == 11){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, HomeTeam, AwayTeam, HS, AS, HST, AST, HF, HC, AC, HR, AR)
            }
            else if(input$preds == 10){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, HomeTeam, AwayTeam, HS, AS, HST, AST, HC, AC, HR, AR)
            }
            else if(input$preds == 9){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, AwayTeam, HS, AS, HST, AST, HC, AC, HR, AR)
            }
            else if(input$preds == 8){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, AwayTeam, HS, AS, HST, AST, AC, HR, AR)
            }
            else if(input$preds == 7){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, HS, AS, HST, AST, AC, HR, AR)
            }
            else if(input$preds == 6){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, HS, AS, HST, AST, HR, AR)
            }
            else if(input$preds == 5){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, HS, AS, HST, AST, AR)
            }
            else if(input$preds == 4){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, HS, AS, HST, AST)
            }
            else if(input$preds == 3){
                xTrain <- data2 %>% filter(Season != "18-19") %>% 
                    select(RES, HS, HST, AST)
            }
            
                set.seed(1234)
                
                    ## Random Forest
                    trctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 1)
                    
                    model <- train(RES ~ ., data = xTrain,
                                   method = "rf",
                                   tuneLength = 3,
                                   trControl = trctrl)
                    
                    finModel <- plot(model$finalModel, main = "Final Random Forest Model")
                    finModel
                })
        })
        
        # Table listing Predicted vs Actual Predict
        output$overall <- renderDataTable({
            
            # Set up Predictors
            if(input$preds == 13){
                colPreds <- c("Matchday", "HomeTeam", "AwayTeam", "HS", 
                              "AS", "HST", "AST", "HF", "AF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 12){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", "HST", "AST",
                              "HF", "AF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 11){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", "HST", 
                              "AST", "HF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 10){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", 
                              "HST", "AST", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 9){
                colPreds <- c("AwayTeam", "HS", "AS", "HST", "AST", "HC", 
                              "AC", "HR", "AR")
            }
            else if(input$preds == 8){
                colPreds <- c("AwayTeam", "HS", "AS", "HST", "AST", "AC", "HR", "AR")
            }
            else if(input$preds == 7){
                colPreds <- c("HS", "AS", "HST", "AST", "AC", "HR", "AR")
            }
            else if(input$preds == 6){
                colPreds <- c("HS", "AS", "HST", "AST", "HR", "AR")
            }
            else if(input$preds == 5){
                colPreds <- c("HS", "AS", "HST", "AST", "HR")
            }
            else if(input$preds == 4){
                colPreds <- c("HS", "AS", "HST", "AST")
            }
            else if(input$preds == 3){
                colPreds <- c("HS", "HST", "AST")
            }
            
            #Train/Test data - 2013-2018 Seasons Train, 2018-2019 Season Test
            xTrain <- data2[1:1900, colPreds]
            xTest <- data2[1901:2280, colPreds]
            
            yTrain <- as.factor(data2[1:1900,]$RES)
            yTest <- as.factor(data2[1901:2280,]$RES)
            
            set.seed(1234)
            
            ## Random Forest
            trctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 1)
            
            suppressWarnings( 
            model <- train(xTrain, yTrain,
                           method = "rf",
                           strata = yTrain,
                           tuneLength = 3,
                           trControl = trctrl))
            
            #Prediction
            rfPred <- predict(model, xTest)
            
            #Creating Table showing Comparison between Predicted vs Actual
            teamNames <- data2 %>% filter(Season == "18-19")
            
            overall <- as_tibble(cbind(teamNames$HomeTeam, teamNames$AwayTeam, yTest, rfPred))
            
            overall$yTest <- ifelse(overall$yTest == "1", "A", 
                                    ifelse(overall$yTest == "2", "D", "H"))
            
            overall$rfPred <- ifelse(overall$rfPred == "1", "A", 
                                     ifelse(overall$rfPred == "2", "D", "H"))
            
            overall <- overall %>% mutate(Correct = ifelse(yTest == rfPred, "Yes", "No")) %>% 
                                    rename("Home Team" = V1, "Away Team" = V2,
                                           "Actual Result" = yTest, "Predicted Result" = rfPred)
            overall
        })
        
        # RF Accuracy and Misclassification
        output$accMatrix <- renderTable({
            
            # Set up Predictors
            if(input$preds == 13){
                colPreds <- c("Matchday", "HomeTeam", "AwayTeam", "HS", 
                              "AS", "HST", "AST", "HF", "AF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 12){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", "HST", "AST",
                              "HF", "AF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 11){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", "HST", 
                              "AST", "HF", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 10){
                colPreds <- c("HomeTeam", "AwayTeam", "HS", "AS", 
                              "HST", "AST", "HC", "AC", "HR", "AR")
            }
            else if(input$preds == 9){
                colPreds <- c("AwayTeam", "HS", "AS", "HST", "AST", "HC", 
                              "AC", "HR", "AR")
            }
            else if(input$preds == 8){
                colPreds <- c("AwayTeam", "HS", "AS", "HST", "AST", "AC", "HR", "AR")
            }
            else if(input$preds == 7){
                colPreds <- c("HS", "AS", "HST", "AST", "AC", "HR", "AR")
            }
            else if(input$preds == 6){
                colPreds <- c("HS", "AS", "HST", "AST", "HR", "AR")
            }
            else if(input$preds == 5){
                colPreds <- c("HS", "AS", "HST", "AST", "HR")
            }
            else if(input$preds == 4){
                colPreds <- c("HS", "AS", "HST", "AST")
            }
            else if(input$preds == 3){
                colPreds <- c("HS", "HST", "AST")
            }
            
            #Train/Test data - 2013-2018 Seasons Train, 2018-2019 Season Test
            xTrain <- data2[1:1900, colPreds]
            xTest <- data2[1901:2280, colPreds]
            
            yTrain <- as.factor(data2[1:1900,]$RES)
            yTest <- as.factor(data2[1901:2280,]$RES)
            
            set.seed(1234)
            
            ## Random Forest
            trctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 1)
            
            suppressWarnings(
            model <- train(xTrain, yTrain,
                           method = "rf",
                           strata = yTrain,
                           tuneLength = 3,
                           trControl = trctrl))
            
            #Prediction
            rfPred <- predict(model, xTest)
            
            # Create Table
            tbl <- table(rfPred, yTest)
            
            #Create Table with Accuracies and Misclassifications
            accMatrix <- matrix(c(paste0(round((mean(rfPred == yTest))*100, 2), "%"), 
                               paste0(round((tbl[3,3]/(tbl[3,3] + tbl[3,1] + tbl[3,2]))*100, 2), "%"),
                               paste0(round((tbl[1,1]/(tbl[1,1] + tbl[1,2] + tbl[1,3]))*100, 2), "%"),
                               paste0(round((tbl[2,2]/(tbl[2,2] + tbl[2,1] + tbl[2,3]))*100, 2), "%"),
                               paste0(round((mean(rfPred != yTest))*100, 2), "%"),
                               paste0(round(((tbl[3,1] + tbl[3,2])/(tbl[3,3] + tbl[3,1] + tbl[3,2]))*100, 2), "%"),
                               paste0(round(((tbl[1,2] + tbl[1,3])/(tbl[1,1] + tbl[1,2] + tbl[1,3]))*100, 2), "%"),
                               paste0(round(((tbl[2,1] + tbl[2,3])/(tbl[2,2] + tbl[2,1] + tbl[2,3]))*100, 2), "%")),
                               ncol = 2, nrow = 4,
                               dimnames = list(c("Overall", "Home", "Away", "Draw"),
                                               c("Accuracy", "Misclassification")))
            accMatrix
        }, rownames = TRUE)
        
# Scroll Data
        
        # View Teams Schedules by season
        output$schedule <- renderTable({
            
            #Filter season and Team
            if(input$match == "All Seasons" & input$team != "All Teams"){
                data3 <- data3 %>% filter(HomeTeam == input$team | AwayTeam == input$team) 
                data3 <- data3 %>% unite("FinalScore", HTG, ATG, sep = " - ")
                data3[,8:21] <- lapply(data3[,8:21], as.integer)
                data3$Matchday <- as.integer(data3$Matchday)
                data3
            }
            else if(input$match != "All Seasons" & input$team == "All Teams"){
                data3 <- data3 %>% filter(Season == input$match)
                data3 <- data3 %>% unite("FinalScore", HTG, ATG, sep = " - ")
                data3[,8:21] <- lapply(data3[,8:21], as.integer)
                data3$Matchday <- as.integer(data3$Matchday)
                data3
            }
            else if(input$match != "All Seasons" & input$team != "All Teams"){
                data3 <- data3 %>% filter(Season == input$match)
                data3 <- data3 %>% filter(HomeTeam == input$team | AwayTeam == input$team) 
                data3 <- data3 %>% unite("FinalScore", HTG, ATG, sep = " - ")
                data3[,8:21] <- lapply(data3[,8:21], as.integer)
                data3$Matchday <- as.integer(data3$Matchday)
                data3
            }
            else{
                data3 <- data3 %>% unite("FinalScore", HTG, ATG, sep = " - ")
                data3[,8:21] <- lapply(data3[,8:21], as.integer)
                data3$Matchday <- as.integer(data3$Matchday)
                data3
            }
        })
        
# Money Table
        
       # Transfer Expenditure
        makePlot <- reactive({
            
            join2 <- join %>% filter(Season == input$seas, Transfer == "Winter") %>% 
                select(Season, Club, `Final Ranking`, RD, Expenditure, Transfer) %>% 
                arrange(`Final Ranking`)
            
            plots <- function(x){
                par(mar=c(5.9, 4.1, 2.3, 4))
                
                barplot(join2$Expenditure ~ join2$Club, xlab = "", ylab = "", 
                        las = 2, ylim = c(0,100), xaxt = "n", col = "mediumseagreen")
                
                par(new = TRUE) 
                plot(join2$`Final Ranking`,join2$RD, type = "o", xaxt = "n", yaxt = "n", 
                     xlab = "", ylab = "", col = "royalblue3", lwd = 2, pch = 15) 
                
                abline(h = 0, lty = 2, col = "royalblue3") 
                
                text(x = 1:20,
                     y = par("usr")[3] - 0.10,
                     labels = join2$Club,
                     xpd = NA, 
                     srt = 50, 
                     cex = 0.75, 
                     adj = .95) 
                
                axis(side = 4, at = pretty(range(join2$RD))) 
                mtext("League Position +/-", side = 4, line = 2, cex = .90) 
                mtext("Transfer Spending (in Millions \u20AC)", side = 2, line = 2.5, cex = .90) 
                mtext("Winter Transfer Expenditure", side = 3, line = 1)
            }
            transfer <- plots(join)
            transfer
        })
        
        output$transfer <- renderPlot({
            print(makePlot())
        })
        
        output$downloadGraph <- downloadHandler(
            filename = function(){paste(input$seas, '.png', sep='')},
            content = function(file){
                png(file)
                makePlot()
                dev.off()
            },
        )
            
        
        #Table for Transfer Money
        output$money <- renderTable({
            join3 <- join %>% filter(Season == input$seas, Transfer == "Winter") %>% 
                select(Season, Club, EndJan, `Final Ranking`, Expenditure, Transfer) %>% 
                arrange(`Final Ranking`)
            
            join3 <- join3 %>% select(EndJan, `Final Ranking`, Club, Expenditure) %>% 
                rename("Exenditure (in Millions \u20AC)" = Expenditure, "Midseason Rank" = EndJan)
            
            join3$`Final Ranking` <- as.integer(join3$`Final Ranking`)
            join3$`Midseason Rank` <- as.integer(join3$`Midseason Rank`)
            
            money <- lapply(join3[,4], function(x){paste(x, "\u20AC", sep = " ")})
            
            join3 <- join3 %>% select(- `Exenditure (in Millions €)`)
            
            monies <- cbind(join3, money)
            
            monies
        })
})

