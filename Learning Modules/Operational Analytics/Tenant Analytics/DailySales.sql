-- View for Daily sale by venues
CREATE VIEW [dbo].[DailySalesByVenue]
AS
SELECT VenueName
      ,SaleDay= (DaysToGo) 
      ,RunningTicketsSoldTotal = sum(MAX(RunningTicketsSold)) over (PArtition by VenueName order by DaysToGO ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
FROM (
SELECT v.VenueName
      ,s.DaysToGo
      ,RunningTicketsSold = COUNT(*) OVER (PArtition by VenueName,DaysToGo) 
  FROM fact_Tickets s
  JOIN dim_Venues v
    ON s.VenueID = v.VenueID
  JOIN dim_Dates d
    ON d.PurchaseDateID = s.PurchaseDateID
)A		
GROUP BY VenueName
        ,DaysToGo
GO

-- View for Daily sale by events
CREATE VIEW [dbo].[DailySalesByEvent]
AS
SELECT VenueName
	  ,EventName
	  ,SaleDay = (60-DaysToGo)
      ,RunningTicketsSoldTotal = MAX(RunningTicketsSold)
	  ,Event = VenueName+'+'+EventName
FROM (
SELECT V.VenueName
	  ,E.EventName
	  ,DaysToGo = T.DaysToGo
      ,RunningTicketsSold = COUNT(*) OVER (Partition by EventName+VenueName Order by T.PurchaseDateID)
FROM [dbo].[fact_Tickets] T
JOIN [dbo].[dim_Venues] V
ON V.VenueId = T. VenueId
JOIN [dbo].[dim_Events] E
ON E.EventId = T. EventId AND E.VenueId = T.VenueId
JOIN [dbo].[dim_Dates] D
ON  D.PurchaseDateID = T.PurchaseDateID
)A
GROUP BY VenueName
		,EventName
		,DaysToGo
GO

-- Query the view to display the information
SELECT * FROM [dbo].[DailySalesByVenue]

SELECT * FROM [dbo].[DailySalesByEvent]