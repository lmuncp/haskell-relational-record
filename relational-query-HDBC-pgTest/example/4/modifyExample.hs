{-# LANGUAGE FlexibleContexts #-}

import Prelude hiding (seq)
import Database.HDBC (IConnection, SqlValue, commit)
import Database.Record
import Database.Relational.Query
import Database.HDBC.Record
import Database.HDBC.Session
import Stock
import PgTestDataSource

import Data.Int (Int32)

stocks0 :: [Stock]
stocks0 =  [ Stock 1 "Apple"  110 40
           , Stock 2 "Orange" 150 30
           , Stock 3 "Banana" 90  15
           , Stock 4 "Cherry" 200 5
           ]

handleConnectionIO :: IConnection conn => IO conn -> (conn -> IO a) -> IO a
handleConnectionIO c p = handleSqlError' $ withConnectionIO c p

runInsertStocks :: [Stock] -> IO ()
runInsertStocks ss = handleConnectionIO connect $ \conn -> do
  let q =  insertStock
  putStrLn $ "SQL: " ++ show q
  rvs  <- mapInsert conn q ss
  print rvs
  commit conn

runInsertStocks0 :: IO ()
runInsertStocks0 =  runInsertStocks stocks0


pine :: Relation () Stock
pine =  relation $ do
  return $ Stock |$| value 6 |*| value "Pine" |*| value 300 |*| value 3

insertPine :: InsertQuery ()
insertPine =  typedInsertQuery tableOfStock pine

fig :: Relation () Stock
fig =  relation $ do
  return $ Stock |$| value 7 |*| value "Fig" |*| value 200 |*| value 13

insertFig :: InsertQuery ()
insertFig =  insertQueryStock fig

runInsertQuery1 :: InsertQuery () -> IO ()
runInsertQuery1 ins = handleConnectionIO connect $ \conn -> do
  _ <- runInsertQuery conn ins ()
  commit conn

riseOfBanana :: Update ()
riseOfBanana =  typedUpdate tableOfStock . updateTarget $ \tbl proj -> do
  tbl !# unit' <-# proj ! unit' .*. value 2
  wheres $ proj ! name' .=. value "Banana"


newCherry :: Stock
newCherry =  Stock 5 "Black Cherry" 190 50

updateCherry :: Update (Stock, (Int32, String))
updateCherry =  typedUpdate tableOfStock . updateTargetAllColumn' $ \proj -> do
  (ph', ()) <- placeholder (\ph -> wheres $ proj ! (seq' >< name') .=. ph)
  return ph'

runUpdateAndPrint :: ToSql SqlValue p => Update p -> p -> IO ()
runUpdateAndPrint u p = handleConnectionIO connect $ \conn -> do
  putStrLn $ "SQL: " ++ show u
  rv <- runUpdate conn u p
  print rv
  commit conn

newOrange :: Stock
newOrange =  Stock 2 "Orange" 150 10

keyUpdateUidName :: KeyUpdate (Int32, String) Stock
keyUpdateUidName =  typedKeyUpdate tableOfStock (seq' >< name')

runKeyUpdateAndPrint :: ToSql SqlValue a => KeyUpdate p a -> a -> IO ()
runKeyUpdateAndPrint ku r = handleConnectionIO connect $ \conn -> do
  putStrLn $ "SQL: " ++ show ku
  rv <- runKeyUpdate conn ku r
  print rv
  commit conn

allStock :: IO [Stock]
allStock =  handleConnectionIO connect $ \conn -> do
  let q = stock
  putStrLn $ "SQL: " ++ show q
  runQuery' conn (relationalQuery q) ()

deleteStock :: Delete Int32
deleteStock =  typedDelete tableOfStock . restriction' $ \proj -> do
  (ph', ()) <- placeholder (\ph -> wheres $ proj ! seq' .=. ph)
  return ph'

runDeleteStocks :: ToSql SqlValue a => Delete a -> [a] -> IO ()
runDeleteStocks d xs = handleConnectionIO connect $ \conn -> do
  putStrLn $ "SQL: " ++ show d
  ps  <- prepareDelete conn d
  rvs <- mapM (runPreparedDelete ps) xs
  print rvs
  commit conn

run :: IO ()
run = do
  runInsertStocks0
  runInsertQuery1 insertPine
  runInsertQuery1 insertFig
  runUpdateAndPrint riseOfBanana ()
  runUpdateAndPrint updateCherry (newCherry, (4, "Cherry"))
  runKeyUpdateAndPrint keyUpdateUidName newOrange
  ss <- allStock
  mapM_ print ss
  runDeleteStocks deleteStock (map seq ss)

main :: IO ()
main =  run
