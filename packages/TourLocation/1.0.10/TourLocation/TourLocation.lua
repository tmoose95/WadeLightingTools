-- Tour Location v1.0.10 for grandMA3 2.4
-- Worldwide touring-market location presets with venue notes.

local pluginName, componentName, signalTable, myHandle = ...

local function safe(fn, fallback)
 local ok,value=pcall(fn)
 if ok then return value end
 return fallback
end

local function ensureUtilityTag()
 local tagName='Utility Plugins'
 local function findTag()
  local list=safe(function() return ObjectList('Tag Thru') end,{}) or {}
  for _,candidate in ipairs(list) do
   local name=safe(function() return candidate:Get("Name") end,safe(function() return candidate.Name end,""))
   if tostring(name or ""):lower()==tagName:lower() then return candidate end
  end
  return nil
 end
 local tag=findTag()
 if not tag then
  safe(function() Cmd('Store Tag "'..tagName..'" /NoConfirmation') end,nil)
  tag=findTag()
 end
 local plugin=safe(function() return myHandle:Parent() end,nil)
 local tagIndex=tag and tonumber(safe(function() return Obj.Index(tag) end,nil)) or nil
 local pluginIndex=plugin and tonumber(safe(function() return Obj.Index(plugin) end,nil)) or nil
 if tagIndex and pluginIndex then
  local pluginHandle=safe(function() return HandleToInt(plugin) end,nil)
  local references=safe(function() return tag:GetReferences() end,{}) or {}
  for _,reference in pairs(references) do
   if reference==plugin or (pluginHandle and safe(function() return HandleToInt(reference) end,nil)==pluginHandle) then return end
  end
  safe(function() Cmd('Assign Tag '..tagIndex..' At Plugin '..pluginIndex..' Property "Tags" /NoConfirmation') end,nil)
 end
end

local function bindPluginAppearance()
 safe(function()
  local plugin=myHandle:Parent()
  local appearance=Root().ShowData.Appearances.TourLocation
  if plugin and appearance then plugin.Appearance=appearance end
 end,nil)
end

local cities = {
 {"North America","USA","Dallas, TX",32.7767,-96.7970,-6,"us",{"AT&T Stadium","American Airlines Center","Dos Equis Pavilion"}},
 {"North America","USA","Denver, CO",39.7392,-104.9903,-7,"us",{"Empower Field at Mile High","Ball Arena","Fiddler's Green Amphitheatre"}},
 {"North America","USA","Los Angeles, CA",34.0522,-118.2437,-8,"us",{"SoFi Stadium","Crypto.com Arena","Hollywood Bowl"}},
 {"North America","USA","New York, NY",40.7128,-74.0060,-5,"us",{"MetLife Stadium","Madison Square Garden","Forest Hills Stadium"}},
 {"North America","USA","Chicago, IL",41.8781,-87.6298,-6,"us",{"Soldier Field","United Center","Credit Union 1 Amphitheatre"}},
 {"North America","USA","Miami, FL",25.7617,-80.1918,-5,"us",{"Hard Rock Stadium","Kaseya Center","Amerant Bank Arena"}},
 {"North America","USA","Nashville, TN",36.1627,-86.7816,-6,"us",{"Nissan Stadium","Bridgestone Arena","Ascend Amphitheater"}},
 {"North America","USA","Albany, NY",42.6526,-73.7562,-5,"us",{"MVP Arena","The Egg","Palace Theatre"}},
 {"North America","USA","Albuquerque, NM",35.0844,-106.6504,-7,"us",{"Isleta Amphitheater","Tingley Coliseum","Rio Rancho Events Center"}},
 {"North America","USA","Anchorage, AK",61.2181,-149.9003,-9,"us",{"Alaska Airlines Center","Sullivan Arena","Alaska State Fair Borealis Theatre"}},
 {"North America","USA","Atlanta, GA",33.7490,-84.3880,-5,"us",{"Mercedes-Benz Stadium","State Farm Arena","Lakewood Amphitheatre"}},
 {"North America","USA","Austin, TX",30.2672,-97.7431,-6,"us",{"Moody Center","Germania Insurance Amphitheater","Q2 Stadium"}},
 {"North America","USA","Baltimore, MD",39.2904,-76.6122,-5,"us",{"M&T Bank Stadium","CFG Bank Arena","Pier Six Pavilion"}},
 {"North America","USA","Birmingham, AL",33.5186,-86.8104,-6,"us",{"Protective Stadium","Legacy Arena","Oak Mountain Amphitheatre"}},
 {"North America","USA","Boise, ID",43.6150,-116.2023,-7,"us",{"ExtraMile Arena","Ford Idaho Center Arena","Outlaw Field"}},
 {"North America","USA","Boston, MA",42.3601,-71.0589,-5,"us",{"Gillette Stadium","TD Garden","Fenway Park"}},
 {"North America","USA","Bristow, VA",38.7228,-77.5361,-5,"us",{"Jiffy Lube Live"}},
 {"North America","USA","Buffalo, NY",42.8864,-78.8784,-5,"us",{"Highmark Stadium","KeyBank Center","Artpark Amphitheater"}},
 {"North America","USA","Camden, NJ",39.9259,-75.1196,-5,"us",{"Freedom Mortgage Pavilion"}},
 {"North America","USA","Charlotte, NC",35.2271,-80.8431,-5,"us",{"Bank of America Stadium","Spectrum Center","PNC Music Pavilion"}},
 {"North America","USA","Charleston, SC",32.7765,-79.9311,-5,"us",{"Credit One Stadium","North Charleston Coliseum","The Refinery"}},
 {"North America","USA","Chula Vista, CA",32.6401,-117.0842,-8,"us",{"North Island Credit Union Amphitheatre"}},
 {"North America","USA","Cincinnati, OH",39.1031,-84.5120,-5,"us",{"Paycor Stadium","Heritage Bank Center","Riverbend Music Center"}},
 {"North America","USA","Clarkston, MI",42.7359,-83.4188,-5,"us",{"Pine Knob Music Theatre"}},
 {"North America","USA","Cleveland, OH",41.4993,-81.6944,-5,"us",{"Huntington Bank Field","Rocket Arena","Jacobs Pavilion"}},
 {"North America","USA","Columbia, MD",39.2037,-76.8610,-5,"us",{"Merriweather Post Pavilion"}},
 {"North America","USA","Columbus, OH",39.9612,-82.9988,-5,"us",{"Ohio Stadium","Nationwide Arena","Historic Crew Stadium"}},
 {"North America","USA","Cuyahoga Falls, OH",41.1339,-81.4846,-5,"us",{"Blossom Music Center"}},
 {"North America","USA","Des Moines, IA",41.5868,-93.6250,-6,"us",{"Wells Fargo Arena","Iowa State Fair Grandstand","Water Works Park"}},
 {"North America","USA","Detroit, MI",42.3314,-83.0458,-5,"us",{"Ford Field","Little Caesars Arena","Comerica Park"}},
 {"North America","USA","El Paso, TX",31.7619,-106.4850,-7,"us",{"Sun Bowl Stadium","Don Haskins Center","El Paso County Coliseum"}},
 {"North America","USA","Fresno, CA",36.7378,-119.7871,-8,"us",{"Save Mart Center","Selland Arena","Woodward Park Amphitheater"}},
 {"North America","USA","Grand Rapids, MI",42.9634,-85.6681,-5,"us",{"Van Andel Arena","Acrisure Amphitheater","GLC Live at 20 Monroe"}},
 {"North America","USA","Green Bay, WI",44.5133,-88.0133,-6,"us",{"Lambeau Field","Resch Center","Capital Credit Union Park"}},
 {"North America","USA","Hartford, CT",41.7658,-72.6734,-5,"us",{"XL Center","Xfinity Theatre","Dillon Stadium"}},
 {"North America","USA","Holmdel, NJ",40.3451,-74.1840,-5,"us",{"PNC Bank Arts Center"}},
 {"North America","USA","Honolulu, HI",21.3099,-157.8581,-10,"none",{"Aloha Stadium","Neal S. Blaisdell Arena","Tom Moffatt Waikiki Shell"}},
 {"North America","USA","Houston, TX",29.7604,-95.3698,-6,"us",{"NRG Stadium","Toyota Center","Cynthia Woods Mitchell Pavilion"}},
 {"North America","USA","Indianapolis, IN",39.7684,-86.1581,-5,"us",{"Lucas Oil Stadium","Gainbridge Fieldhouse","Everwise Amphitheater"}},
 {"North America","USA","Jacksonville, FL",30.3322,-81.6557,-5,"us",{"EverBank Stadium","VyStar Veterans Memorial Arena","Daily's Place"}},
 {"North America","USA","Kansas City, MO",39.0997,-94.5786,-6,"us",{"Arrowhead Stadium","T-Mobile Center","Starlight Theatre"}},
 {"North America","USA","Las Vegas, NV",36.1699,-115.1398,-8,"us",{"Allegiant Stadium","T-Mobile Arena","Sphere"}},
 {"North America","USA","Little Rock, AR",34.7465,-92.2896,-6,"us",{"Simmons Bank Arena","War Memorial Stadium","First Security Amphitheater"}},
 {"North America","USA","Louisville, KY",38.2527,-85.7585,-5,"us",{"L&N Federal Credit Union Stadium","KFC Yum! Center","Iroquois Amphitheater"}},
 {"North America","USA","Mansfield, MA",42.0334,-71.2189,-5,"us",{"Xfinity Center"}},
 {"North America","USA","Memphis, TN",35.1495,-90.0490,-6,"us",{"Simmons Bank Liberty Stadium","FedExForum","Radians Amphitheater"}},
 {"North America","USA","Milwaukee, WI",43.0389,-87.9065,-6,"us",{"American Family Field","Fiserv Forum","American Family Insurance Amphitheater"}},
 {"North America","USA","Minneapolis, MN",44.9778,-93.2650,-6,"us",{"U.S. Bank Stadium","Target Center","Huntington Bank Stadium"}},
 {"North America","USA","New Orleans, LA",29.9511,-90.0715,-6,"us",{"Caesars Superdome","Smoothie King Center","Champions Square"}},
 {"North America","USA","Noblesville, IN",40.0456,-86.0086,-5,"us",{"Ruoff Music Center"}},
 {"North America","USA","Oklahoma City, OK",35.4676,-97.5164,-6,"us",{"Paycom Center","Chickasaw Bricktown Ballpark","The Zoo Amphitheatre"}},
 {"North America","USA","Omaha, NE",41.2565,-95.9345,-6,"us",{"CHI Health Center Omaha","Charles Schwab Field","The Astro Amphitheater"}},
 {"North America","USA","Orlando, FL",28.5383,-81.3792,-5,"us",{"Camping World Stadium","Kia Center","Addition Financial Arena"}},
 {"North America","USA","Philadelphia, PA",39.9526,-75.1652,-5,"us",{"Lincoln Financial Field","Wells Fargo Center","The Mann Center"}},
 {"North America","USA","Phoenix, AZ",33.4484,-112.0740,-7,"none",{"State Farm Stadium","PHX Arena","Talking Stick Resort Amphitheatre"}},
 {"North America","USA","Pittsburgh, PA",40.4406,-79.9959,-5,"us",{"Acrisure Stadium","PPG Paints Arena","Stage AE"}},
 {"North America","USA","Portland, ME",43.6591,-70.2568,-5,"us",{"Cross Insurance Arena","Maine Savings Amphitheater","Thompson's Point"}},
 {"North America","USA","Portland, OR",45.5152,-122.6784,-8,"us",{"Moda Center","Providence Park","Hayden Homes Amphitheater"}},
 {"North America","USA","Providence, RI",41.8240,-71.4128,-5,"us",{"Amica Mutual Pavilion","Bold Point Park","Veterans Memorial Auditorium"}},
 {"North America","USA","Raleigh, NC",35.7796,-78.6382,-5,"us",{"Lenovo Center","Coastal Credit Union Music Park","Carter-Finley Stadium"}},
 {"North America","USA","Richmond, VA",37.5407,-77.4360,-5,"us",{"Allianz Amphitheater at Riverfront","Richmond Coliseum","City Stadium"}},
 {"North America","USA","Sacramento, CA",38.5816,-121.4944,-8,"us",{"Golden 1 Center","Toyota Amphitheatre","Sutter Health Park"}},
 {"North America","USA","Salt Lake City, UT",40.7608,-111.8910,-7,"us",{"Rice-Eccles Stadium","Delta Center","Utah First Credit Union Amphitheatre"}},
 {"North America","USA","San Antonio, TX",29.4241,-98.4936,-6,"us",{"Alamodome","Frost Bank Center","Toyota Field"}},
 {"North America","USA","San Diego, CA",32.7157,-117.1611,-8,"us",{"Snapdragon Stadium","Pechanga Arena","The Rady Shell"}},
 {"North America","USA","San Francisco, CA",37.7749,-122.4194,-8,"us",{"Oracle Park","Chase Center","Bill Graham Civic Auditorium"}},
 {"North America","USA","San Jose, CA",37.3382,-121.8863,-8,"us",{"Levi's Stadium","SAP Center","Shoreline Amphitheatre"}},
 {"North America","USA","Seattle, WA",47.6062,-122.3321,-8,"us",{"Lumen Field","Climate Pledge Arena","T-Mobile Park"}},
 {"North America","USA","St. Louis, MO",38.6270,-90.1994,-6,"us",{"The Dome at America's Center","Enterprise Center","Hollywood Casino Amphitheatre"}},
 {"North America","USA","Syracuse, NY",43.0481,-76.1474,-5,"us",{"JMA Wireless Dome","Empower Federal Credit Union Amphitheater","War Memorial Arena"}},
 {"North America","USA","Tampa, FL",27.9506,-82.4572,-5,"us",{"Raymond James Stadium","Benchmark International Arena","MIDFLORIDA Credit Union Amphitheatre"}},
 {"North America","USA","The Woodlands, TX",30.1658,-95.4613,-6,"us",{"Cynthia Woods Mitchell Pavilion"}},
 {"North America","USA","Tinley Park, IL",41.5734,-87.7845,-6,"us",{"Credit Union 1 Amphitheatre"}},
 {"North America","USA","Tulsa, OK",36.1540,-95.9928,-6,"us",{"BOK Center","ONEOK Field","Tulsa Theater"}},
 {"North America","USA","Virginia Beach, VA",36.8529,-75.9780,-5,"us",{"Veterans United Home Loans Amphitheater","Virginia Beach Sports Center","Oceanfront Concert Stage"}},
 {"North America","USA","Washington, DC",38.9072,-77.0369,-5,"us",{"Audi Field","Capital One Arena","The Anthem"}},
 {"North America","USA","West Palm Beach, FL",26.7153,-80.0534,-5,"us",{"iTHINK Financial Amphitheatre","Palm Beach County Convention Center"}},
 {"North America","USA","Bakersfield, CA",35.3733,-119.0187,-8,"us",{"Dignity Health Arena","Mechanics Bank Theater","The Historic Bakersfield Fox Theater"}},
 {"North America","USA","Baton Rouge, LA",30.4515,-91.1871,-6,"us",{"Tiger Stadium","Raising Cane's River Center Arena","L'Auberge Event Center"}},
 {"North America","USA","Billings, MT",45.7833,-108.5007,-7,"us",{"First Interstate Arena","MetraPark Grandstands","Alberta Bair Theater"}},
 {"North America","USA","Bismarck, ND",46.8083,-100.7837,-6,"us",{"Bismarck Event Center","Bismarck Civic Center Arena","Belle Mehus Auditorium"}},
 {"North America","USA","Burlington, VT",44.4759,-73.2121,-5,"us",{"Patrick Gymnasium","Waterfront Park","Higher Ground"}},
 {"North America","USA","Casper, WY",42.8501,-106.3252,-7,"us",{"Ford Wyoming Center","David Street Station","The Gaslight Social"}},
 {"North America","USA","Cedar Rapids, IA",41.9779,-91.6656,-6,"us",{"Alliant Energy PowerHouse","McGrath Amphitheatre","Paramount Theatre"}},
 {"North America","USA","Chattanooga, TN",35.0456,-85.3097,-5,"us",{"McKenzie Arena","Finley Stadium","The Signal"}},
 {"North America","USA","Colorado Springs, CO",38.8339,-104.8214,-7,"us",{"Weidner Field","Broadmoor World Arena","Ford Amphitheater"}},
 {"North America","USA","Eugene, OR",44.0521,-123.0868,-8,"us",{"Autzen Stadium","Matthew Knight Arena","Cuthbert Amphitheater"}},
 {"North America","USA","Fargo, ND",46.8772,-96.7898,-6,"us",{"Fargodome","Scheels Arena","Bluestem Amphitheater"}},
 {"North America","USA","Fort Wayne, IN",41.0793,-85.1394,-5,"us",{"Allen County War Memorial Coliseum","Parkview Field","Foellinger Theatre"}},
 {"North America","USA","Greensboro, NC",36.0726,-79.7920,-5,"us",{"First Horizon Coliseum","White Oak Amphitheatre","Steven Tanger Center"}},
 {"North America","USA","Greenville, SC",34.8526,-82.3940,-5,"us",{"Bon Secours Wellness Arena","Fluor Field","Peace Center Amphitheatre"}},
 {"North America","USA","Huntsville, AL",34.7304,-86.5861,-6,"us",{"The Orion Amphitheater","Propst Arena","Joe Davis Stadium"}},
 {"North America","USA","Jackson, MS",32.2988,-90.1848,-6,"us",{"Mississippi Coliseum","Duling Hall","Brandon Amphitheater"}},
 {"North America","USA","Knoxville, TN",35.9606,-83.9207,-5,"us",{"Neyland Stadium","Thompson-Boling Arena","World's Fair Park"}},
 {"North America","USA","Lexington, KY",38.0406,-84.5037,-5,"us",{"Kroger Field","Rupp Arena","The Burl Outdoors"}},
 {"North America","USA","Lincoln, NE",40.8136,-96.7026,-6,"us",{"Memorial Stadium","Pinnacle Bank Arena","Pinewood Bowl Theater"}},
 {"North America","USA","Madison, WI",43.0731,-89.4012,-6,"us",{"Camp Randall Stadium","Kohl Center","Breese Stevens Field"}},
 {"North America","USA","Manchester, NH",42.9956,-71.4548,-5,"us",{"SNHU Arena","Delta Dental Stadium","Palace Theatre"}},
 {"North America","USA","Mobile, AL",30.6954,-88.0399,-6,"us",{"Hancock Whitney Stadium","Mobile Civic Center Arena","Saenger Theatre"}},
 {"North America","USA","New Haven, CT",41.3083,-72.9279,-5,"us",{"Yale Bowl","Westville Music Bowl","College Street Music Hall"}},
 {"North America","USA","Newark, NJ",40.7357,-74.1724,-5,"us",{"Prudential Center","New Jersey Performing Arts Center","Red Bull Arena"}},
 {"North America","USA","Reno, NV",39.5296,-119.8138,-8,"us",{"Reno Events Center","Lawlor Events Center","Grand Sierra Resort Amphitheater"}},
 {"North America","USA","Rochester, NY",43.1566,-77.6088,-5,"us",{"Blue Cross Arena","Innovative Field","CMAC"}},
 {"North America","USA","Savannah, GA",32.0809,-81.0912,-5,"us",{"Enmarket Arena","Grayson Stadium","Trustees Garden"}},
 {"North America","USA","Sioux Falls, SD",43.5460,-96.7313,-6,"us",{"Denny Sanford Premier Center","Sioux Falls Arena","Levitt at the Falls"}},
 {"North America","USA","Spokane, WA",47.6588,-117.4260,-8,"us",{"Spokane Arena","ONE Spokane Stadium","Northern Quest Amphitheater"}},
 {"North America","USA","Tucson, AZ",32.2226,-110.9747,-7,"none",{"Arizona Stadium","McKale Center","AVA Amphitheater"}},
 {"North America","USA","Wichita, KS",37.6872,-97.3301,-6,"us",{"INTRUST Bank Arena","Wave Outdoor","Hartman Arena"}},
 {"North America","USA","Wilmington, DE",39.7391,-75.5398,-5,"us",{"Chase Fieldhouse","Tubman-Garrett Riverfront Park","The Queen"}},
 {"North America","USA","Charleston, WV",38.3498,-81.6326,-5,"us",{"Charleston Coliseum","Appalachian Power Park","Clay Center"}},
 {"North America","Canada","Toronto, ON",43.6532,-79.3832,-5,"us",{"Rogers Centre","Scotiabank Arena","Budweiser Stage"}},
 {"North America","Canada","Vancouver, BC",49.2827,-123.1207,-8,"us",{"BC Place","Rogers Arena","Pacific Coliseum"}},
 {"North America","Mexico","Mexico City",19.4326,-99.1332,-6,"none",{"Estadio GNP Seguros","Estadio Azteca","Arena CDMX"}},
 {"South America","Brazil","São Paulo",-23.5505,-46.6333,-3,"none",{"Allianz Parque","MorumBIS","Espaço Unimed"}},
 {"South America","Brazil","Rio de Janeiro",-22.9068,-43.1729,-3,"none",{"Maracanã","Farmasi Arena","Estádio Nilton Santos"}},
 {"South America","Argentina","Buenos Aires",-34.6037,-58.3816,-3,"none",{"Estadio River Plate","Movistar Arena","Estadio Vélez Sarsfield"}},
 {"South America","Colombia","Bogotá",4.7110,-74.0721,-5,"none",{"Estadio El Campín","Movistar Arena Bogotá","Coliseo MedPlus"}},
 {"South America","Chile","Santiago",-33.4489,-70.6693,-4,"chile",{"Estadio Nacional","Movistar Arena Santiago","Estadio Monumental"}},
 {"South America","Peru","Lima",-12.0464,-77.0428,-5,"none",{"Estadio Nacional","Estadio San Marcos","Arena 1"}},
 {"Europe","United Kingdom","London",51.5074,-0.1278,0,"eu",{"Wembley Stadium","The O2","Tottenham Hotspur Stadium"}},
 {"Europe","France","Paris",48.8566,2.3522,1,"eu",{"Stade de France","Paris La Défense Arena","Accor Arena"}},
 {"Europe","Germany","Berlin",52.5200,13.4050,1,"eu",{"Olympiastadion Berlin","Uber Arena","Waldbühne"}},
 {"Europe","Spain","Madrid",40.4168,-3.7038,1,"eu",{"Estadio Santiago Bernabéu","Riyadh Air Metropolitano","Movistar Arena Madrid"}},
 {"Europe","Netherlands","Amsterdam",52.3676,4.9041,1,"eu",{"Johan Cruijff ArenA","Ziggo Dome","AFAS Live"}},
 {"Europe","Italy","Rome",41.9028,12.4964,1,"eu",{"Stadio Olimpico","Palazzo dello Sport","Auditorium Parco della Musica"}},
 {"Europe","Sweden","Stockholm",59.3293,18.0686,1,"eu",{"Strawberry Arena","Avicii Arena","3Arena"}},
 {"Asia","Japan","Tokyo",35.6762,139.6503,9,"none",{"Tokyo Dome","Saitama Super Arena","Nippon Budokan"}},
 {"Asia","South Korea","Seoul",37.5665,126.9780,9,"none",{"Seoul World Cup Stadium","KSPO Dome","Gocheok Sky Dome"}},
 {"Asia","Singapore","Singapore",1.3521,103.8198,8,"none",{"National Stadium","Singapore Indoor Stadium","The Star Theatre"}},
 {"Asia","Thailand","Bangkok",13.7563,100.5018,7,"none",{"Rajamangala National Stadium","Impact Arena","Thunder Dome"}},
 {"Asia","Philippines","Manila",14.5995,120.9842,8,"none",{"Philippine Arena","SM Mall of Asia Arena","Araneta Coliseum"}},
 {"Asia","India","Mumbai",19.0760,72.8777,5.5,"none",{"DY Patil Stadium","Jio World Garden","NSCI Dome"}},
 {"Asia","United Arab Emirates","Dubai",25.2048,55.2708,4,"none",{"Coca-Cola Arena","Dubai Media City Amphitheatre","The Sevens Stadium"}},
 {"Africa","South Africa","Johannesburg",-26.2041,28.0473,2,"none",{"FNB Stadium","Ellis Park Stadium","Ticketpro Dome"}},
 {"Africa","South Africa","Cape Town",-33.9249,18.4241,2,"none",{"DHL Stadium","GrandWest Grand Arena","Kirstenbosch Concert Stage"}},
 {"Africa","Egypt","Cairo",30.0444,31.2357,2,"egypt",{"Cairo International Stadium","Cairo International Conference Centre","New Capital Arena"}},
 {"Africa","Nigeria","Lagos",6.5244,3.3792,1,"none",{"Teslim Balogun Stadium","Eko Convention Centre","Eko Atlantic"}},
 {"Africa","Morocco","Casablanca",33.5731,-7.5898,1,"none",{"Stade Mohammed V","Complexe Al Amal","Casablanca Velodrome"}},
 {"Oceania","Australia","Sydney",-33.8688,151.2093,10,"au",{"Accor Stadium","Qudos Bank Arena","Sydney Showground Stadium"}},
 {"Oceania","Australia","Melbourne",-37.8136,144.9631,10,"au",{"Melbourne Cricket Ground","Marvel Stadium","Rod Laver Arena"}},
 {"Oceania","Australia","Brisbane",-27.4698,153.0251,10,"au",{"Suncorp Stadium","Brisbane Entertainment Centre","Riverstage"}},
 {"Oceania","Australia","Perth",-31.9523,115.8613,8,"none",{"Optus Stadium","RAC Arena","Kings Park"}},
 {"Oceania","New Zealand","Auckland",-36.8509,174.7645,12,"nz",{"Eden Park","Spark Arena","Western Springs Stadium"}},
 {"Antarctica","Antarctica","McMurdo Station",-77.8419,166.6863,12,"nz",{"No regular commercial stadium, arena, or shed venue"}},
}

-- v1 worldwide touring-market expansion.
local worldwideCities = {
 {"North America","Canada","Montreal, QC",45.5019,-73.5674,-5,"us",{"Olympic Stadium","Bell Centre","Place Bell"}},
 {"North America","Canada","Ottawa, ON",45.4215,-75.6972,-5,"us",{"Canadian Tire Centre","TD Place Stadium","TD Place Arena"}},
 {"North America","Canada","Calgary, AB",51.0447,-114.0719,-7,"us",{"Scotiabank Saddledome","McMahon Stadium","Grey Eagle Event Centre"}},
 {"North America","Canada","Edmonton, AB",53.5461,-113.4938,-7,"us",{"Commonwealth Stadium","Rogers Place","Edmonton EXPO Centre"}},
 {"North America","Canada","Winnipeg, MB",49.8951,-97.1384,-6,"us",{"Princess Auto Stadium","Canada Life Centre","Burton Cummings Theatre"}},
 {"North America","Canada","Quebec City, QC",46.8139,-71.2080,-5,"us",{"Videotron Centre","PEPS Stadium","Agora du Port de Québec"}},
 {"North America","Canada","Halifax, NS",44.6488,-63.5752,-4,"us",{"Scotiabank Centre","The Wanderers Grounds","Halifax Forum"}},
 {"North America","Canada","Hamilton, ON",43.2557,-79.8711,-5,"us",{"Hamilton Stadium","TD Coliseum","FirstOntario Concert Hall"}},
 {"North America","Mexico","Guadalajara",20.6597,-103.3496,-6,"none",{"Estadio Akron","Arena Guadalajara","Auditorio Telmex"}},
 {"North America","Mexico","Monterrey",25.6866,-100.3161,-6,"none",{"Estadio BBVA","Arena Monterrey","Auditorio Citibanamex"}},
 {"North America","Mexico","Puebla",19.0414,-98.2063,-6,"none",{"Estadio Cuauhtémoc","Auditorio GNP Seguros","Arena BUAP"}},
 {"North America","Mexico","Tijuana",32.5149,-117.0382,-8,"us",{"Estadio Caliente","Audiorama El Trompo","Plaza Monumental"}},
 {"North America","Mexico","Cancún",21.1619,-86.8515,-5,"none",{"Estadio Andrés Quintana Roo","Plaza de Toros Cancún","Moon Palace Arena"}},
 {"North America","Costa Rica","San José",9.9281,-84.0907,-6,"none",{"Estadio Nacional de Costa Rica","Parque Viva","Palacio de los Deportes"}},
 {"North America","Panama","Panama City",8.9824,-79.5199,-5,"none",{"Estadio Rommel Fernández","Arena Roberto Durán","Figali Convention Center"}},
 {"North America","Guatemala","Guatemala City",14.6349,-90.5069,-6,"none",{"Estadio Doroteo Guamuch Flores","Forum Majadas","Domo Polideportivo"}},
 {"North America","El Salvador","San Salvador",13.6929,-89.2182,-6,"none",{"Estadio Cuscatlán","Gimnasio Nacional","Complejo Estadio Mágico González"}},
 {"North America","Dominican Republic","Santo Domingo",18.4861,-69.9312,-4,"none",{"Estadio Olímpico Félix Sánchez","Palacio de los Deportes","Anfiteatro Nuryn Sanlley"}},
 {"North America","Puerto Rico","San Juan",18.4655,-66.1057,-4,"none",{"Estadio Hiram Bithorn","Coliseo de Puerto Rico","Coca-Cola Music Hall"}},
 {"North America","Jamaica","Kingston",18.0179,-76.8099,-5,"none",{"National Stadium","Sabina Park","Emancipation Park"}},
 {"North America","Bahamas","Nassau",25.0443,-77.3504,-5,"us",{"Thomas A. Robinson National Stadium","Kendal G. L. Isaacs Gymnasium","Fort Charlotte Grounds"}},
 {"North America","Trinidad and Tobago","Port of Spain",10.6549,-61.5019,-4,"none",{"Hasely Crawford Stadium","Queen's Park Savannah","Jean Pierre Complex"}},

 {"South America","Colombia","Medellín",6.2442,-75.5812,-5,"none",{"Estadio Atanasio Girardot","La Macarena","Plaza Mayor Medellín"}},
 {"South America","Colombia","Cali",3.4516,-76.5320,-5,"none",{"Estadio Pascual Guerrero","Arena Cañaveralejo","Centro de Eventos Valle del Pacífico"}},
 {"South America","Brazil","Belo Horizonte",-19.9167,-43.9345,-3,"none",{"Mineirão","Arena MRV","Expominas"}},
 {"South America","Brazil","Brasília",-15.7939,-47.8828,-3,"none",{"Arena BRB Mané Garrincha","Ginásio Nilson Nelson","Centro de Convenções Ulysses"}},
 {"South America","Brazil","Porto Alegre",-30.0346,-51.2177,-3,"none",{"Estádio Beira-Rio","Arena do Grêmio","Auditório Araújo Vianna"}},
 {"South America","Brazil","Curitiba",-25.4284,-49.2733,-3,"none",{"Ligga Arena","Pedreira Paulo Leminski","Live Curitiba"}},
 {"South America","Argentina","Córdoba",-31.4201,-64.1888,-3,"none",{"Estadio Mario Alberto Kempes","Plaza de la Música","Quality Arena"}},
 {"South America","Uruguay","Montevideo",-34.9011,-56.1645,-3,"none",{"Estadio Centenario","Antel Arena","Velódromo Municipal"}},
 {"South America","Ecuador","Quito",-0.1807,-78.4678,-5,"none",{"Estadio Olímpico Atahualpa","Coliseo General Rumiñahui","Arena Top Media"}},
 {"South America","Ecuador","Guayaquil",-2.1709,-79.9224,-5,"none",{"Estadio Monumental Banco Pichincha","Estadio George Capwell","Coliseo Voltaire Paladines Polo"}},
 {"South America","Paraguay","Asunción",-25.2637,-57.5759,-3,"none",{"Estadio Defensores del Chaco","SND Arena","Jockey Club del Paraguay"}},
 {"South America","Bolivia","La Paz",-16.4897,-68.1193,-4,"none",{"Estadio Hernando Siles","Teatro al Aire Libre","Campo Ferial Chuquiago Marka"}},
 {"South America","Bolivia","Santa Cruz de la Sierra",-17.7833,-63.1821,-4,"none",{"Estadio Ramón Tahuichi Aguilera","Arena Sonilum","Fexpocruz"}},
 {"South America","Venezuela","Caracas",10.4806,-66.9036,-4,"none",{"Estadio Monumental Simón Bolívar","Poliedro de Caracas","Estadio Olímpico UCV"}},

 {"Europe","United Kingdom","Manchester",53.4808,-2.2426,0,"eu",{"Etihad Stadium","AO Arena","Co-op Live"}},
 {"Europe","United Kingdom","Birmingham",52.4862,-1.8904,0,"eu",{"Villa Park","Utilita Arena Birmingham","bp pulse LIVE"}},
 {"Europe","United Kingdom","Glasgow",55.8642,-4.2518,0,"eu",{"Hampden Park","OVO Hydro","SEC Armadillo"}},
 {"Europe","Ireland","Dublin",53.3498,-6.2603,0,"eu",{"Croke Park","Aviva Stadium","3Arena"}},
 {"Europe","Portugal","Lisbon",38.7223,-9.1393,0,"eu",{"Estádio da Luz","MEO Arena","Passeio Marítimo de Algés"}},
 {"Europe","Portugal","Porto",41.1579,-8.6291,0,"eu",{"Estádio do Dragão","Super Bock Arena","Queimódromo"}},
 {"Europe","Spain","Barcelona",41.3874,2.1686,1,"eu",{"Estadi Olímpic Lluís Companys","Palau Sant Jordi","Parc del Fòrum"}},
 {"Europe","Belgium","Brussels",50.8503,4.3517,1,"eu",{"King Baudouin Stadium","ING Arena","Forest National"}},
 {"Europe","Belgium","Antwerp",51.2194,4.4025,1,"eu",{"Sportpaleis","Lotto Arena","Middenvijver"}},
 {"Europe","Switzerland","Zurich",47.3769,8.5417,1,"eu",{"Letzigrund Stadium","Hallenstadion","The Hall"}},
 {"Europe","Switzerland","Geneva",46.2044,6.1432,1,"eu",{"Stade de Genève","SEG Geneva Arena","Palexpo"}},
 {"Europe","Austria","Vienna",48.2082,16.3738,1,"eu",{"Ernst Happel Stadion","Wiener Stadthalle","Donauinsel"}},
 {"Europe","Denmark","Copenhagen",55.6761,12.5683,1,"eu",{"Parken Stadium","Royal Arena","KB Hallen"}},
 {"Europe","Norway","Oslo",59.9139,10.7522,1,"eu",{"Ullevaal Stadion","Unity Arena","Oslo Spektrum"}},
 {"Europe","Finland","Helsinki",60.1699,24.9384,2,"eu",{"Olympic Stadium","Veikkaus Arena","Suvilahti"}},
 {"Europe","Poland","Warsaw",52.2297,21.0122,1,"eu",{"PGE Narodowy","COS Torwar","Progresja Summer Stage"}},
 {"Europe","Poland","Kraków",50.0647,19.9450,1,"eu",{"TAURON Arena Kraków","Stadion Miejski","Park Lotników"}},
 {"Europe","Czechia","Prague",50.0755,14.4378,1,"eu",{"Fortuna Arena","O2 Arena Prague","Letňany Airport"}},
 {"Europe","Hungary","Budapest",47.4979,19.0402,1,"eu",{"Puskás Aréna","MVM Dome","Budapest Park"}},
 {"Europe","Romania","Bucharest",44.4268,26.1025,2,"eu",{"Arena Națională","Romexpo","Laminor Arena"}},
 {"Europe","Greece","Athens",37.9838,23.7275,2,"eu",{"Olympic Stadium","OAKA Indoor Hall","Plateia Nerou"}},
 {"Europe","Turkey","Istanbul",41.0082,28.9784,3,"none",{"Atatürk Olympic Stadium","Ülker Sports Arena","KüçükÇiftlik Park"}},
 {"Europe","Croatia","Zagreb",45.8150,15.9819,1,"eu",{"Stadion Maksimir","Arena Zagreb","Šalata"}},
 {"Europe","Serbia","Belgrade",44.7866,20.4489,1,"eu",{"Rajko Mitić Stadium","Štark Arena","Tašmajdan Stadium"}},
 {"Europe","Bulgaria","Sofia",42.6977,23.3219,2,"eu",{"Vasil Levski National Stadium","Arena Sofia","Sofia Live Club"}},
 {"Europe","Slovenia","Ljubljana",46.0569,14.5058,1,"eu",{"Stadion Stožice","Arena Stožice","Križanke"}},
 {"Europe","Slovakia","Bratislava",48.1486,17.1077,1,"eu",{"Tehelné pole","TIPOS Arena","NTC Arena"}},
 {"Europe","Estonia","Tallinn",59.4370,24.7536,2,"eu",{"A. Le Coq Arena","Unibet Arena","Tallinn Song Festival Grounds"}},
 {"Europe","Latvia","Riga",56.9496,24.1052,2,"eu",{"Daugava Stadium","Xiaomi Arena","Mežaparks Great Bandstand"}},
 {"Europe","Lithuania","Vilnius",54.6872,25.2797,2,"eu",{"LFF Stadium","Twinsbet Arena","Vingis Park"}},
 {"Europe","Iceland","Reykjavík",64.1466,-21.9426,0,"none",{"Laugardalsvöllur","Laugardalshöll","Harpa"}},
 {"Europe","Ukraine","Kyiv",50.4501,30.5234,2,"eu",{"Olympic Stadium Kyiv","Palace of Sports","VDNG"}},
 {"Europe","Germany","Hamburg",53.5511,9.9937,1,"eu",{"Volksparkstadion","Barclays Arena","Trabrennbahn Bahrenfeld"}},
 {"Europe","Germany","Munich",48.1351,11.5820,1,"eu",{"Olympiastadion München","SAP Garden","Olympiahalle"}},
 {"Europe","Germany","Cologne",50.9375,6.9603,1,"eu",{"RheinEnergieSTADION","LANXESS arena","Tanzbrunnen"}},
 {"Europe","Germany","Frankfurt",50.1109,8.6821,1,"eu",{"Deutsche Bank Park","Festhalle Frankfurt","Jahrhunderthalle"}},
 {"Europe","Italy","Milan",45.4642,9.1900,1,"eu",{"San Siro Stadium","Unipol Forum","Ippodromo SNAI La Maura"}},
 {"Europe","Italy","Bologna",44.4949,11.3426,1,"eu",{"Stadio Renato Dall'Ara","Unipol Arena","Sequoie Music Park"}},
 {"Europe","Italy","Naples",40.8518,14.2681,1,"eu",{"Stadio Diego Armando Maradona","Palapartenope","Arena Flegrea"}},
 {"Europe","France","Lyon",45.7640,4.8357,1,"eu",{"Groupama Stadium","LDLC Arena","Halle Tony Garnier"}},
 {"Europe","France","Marseille",43.2965,5.3698,1,"eu",{"Orange Vélodrome","Le Dôme","Palais des Sports"}},
 {"Europe","France","Lille",50.6292,3.0573,1,"eu",{"Decathlon Arena Stade Pierre-Mauroy","Zénith de Lille","Aéronef"}},

 {"Asia","Japan","Osaka",34.6937,135.5023,9,"none",{"Kyocera Dome Osaka","Osaka-jō Hall","Yanmar Stadium Nagai"}},
 {"Asia","Japan","Nagoya",35.1815,136.9066,9,"none",{"Vantelin Dome Nagoya","Nippon Gaishi Hall","Port Messe Nagoya"}},
 {"Asia","Japan","Yokohama",35.4437,139.6380,9,"none",{"Nissan Stadium","K-Arena Yokohama","Yokohama Arena"}},
 {"Asia","Japan","Fukuoka",33.5904,130.4017,9,"none",{"Mizuho PayPay Dome","Marine Messe Fukuoka","Fukuoka Sunpalace"}},
 {"Asia","China","Beijing",39.9042,116.4074,8,"none",{"National Stadium Bird's Nest","Cadillac Arena","Workers' Stadium"}},
 {"Asia","China","Shanghai",31.2304,121.4737,8,"none",{"Shanghai Stadium","Mercedes-Benz Arena","National Exhibition and Convention Center"}},
 {"Asia","China","Guangzhou",23.1291,113.2644,8,"none",{"Guangdong Olympic Stadium","Guangzhou Gymnasium","Canton Fair Complex"}},
 {"Asia","China","Shenzhen",22.5431,114.0579,8,"none",{"Shenzhen Bay Sports Center","Universiade Center","Shenzhen Concert Hall"}},
 {"Asia","Hong Kong","Hong Kong",22.3193,114.1694,8,"none",{"Kai Tak Stadium","AsiaWorld-Arena","Hong Kong Coliseum"}},
 {"Asia","Taiwan","Taipei",25.0330,121.5654,8,"none",{"Taipei Dome","Taipei Arena","Nangang Exhibition Center"}},
 {"Asia","Malaysia","Kuala Lumpur",3.1390,101.6869,8,"none",{"Bukit Jalil National Stadium","Axiata Arena","Zepp Kuala Lumpur"}},
 {"Asia","Indonesia","Jakarta",-6.2088,106.8456,7,"none",{"Gelora Bung Karno Stadium","Indonesia Arena","Beach City International Stadium"}},
 {"Asia","Vietnam","Ho Chi Minh City",10.8231,106.6297,7,"none",{"Thống Nhất Stadium","Phú Thọ Indoor Stadium","SECC"}},
 {"Asia","Vietnam","Hanoi",21.0278,105.8342,7,"none",{"Mỹ Đình National Stadium","Quần Ngựa Sports Palace","National Convention Center"}},
 {"Asia","India","New Delhi",28.6139,77.2090,5.5,"none",{"Jawaharlal Nehru Stadium","Indira Gandhi Arena","Airia Mall Grounds"}},
 {"Asia","India","Bengaluru",12.9716,77.5946,5.5,"none",{"Sree Kanteerava Stadium","Palace Grounds","Manpho Convention Centre"}},
 {"Asia","India","Hyderabad",17.3850,78.4867,5.5,"none",{"Gachibowli Stadium","GMC Balayogi Athletic Stadium","Hitex Exhibition Center"}},
 {"Asia","India","Chennai",13.0827,80.2707,5.5,"none",{"Jawaharlal Nehru Stadium Chennai","YMCA Grounds","Chennai Trade Centre"}},
 {"Asia","India","Kolkata",22.5726,88.3639,5.5,"none",{"Salt Lake Stadium","Netaji Indoor Stadium","Eco Park"}},
 {"Asia","India","Ahmedabad",23.0225,72.5714,5.5,"none",{"Narendra Modi Stadium","EKA Arena","Riverfront Event Centre"}},
 {"Asia","United Arab Emirates","Abu Dhabi",24.4539,54.3773,4,"none",{"Etihad Park","Etihad Arena","Zayed Sports City Stadium"}},
 {"Asia","Qatar","Doha",25.2854,51.5310,3,"none",{"Lusail Stadium","Ahmad Bin Ali Stadium","Ali Bin Hamad Al Attiyah Arena"}},
 {"Asia","Saudi Arabia","Riyadh",24.7136,46.6753,3,"none",{"King Fahd Sports City","Mohammed Abdo Arena","ANB Arena"}},
 {"Asia","Saudi Arabia","Jeddah",21.4858,39.1925,3,"none",{"King Abdullah Sports City","Jeddah Superdome","Benchmark Theater"}},
 {"Asia","Israel","Tel Aviv",32.0853,34.7818,2,"israel",{"Yarkon Park","Menora Mivtachim Arena","Bloomfield Stadium"}},
 {"Asia","Bahrain","Manama",26.2235,50.5876,3,"none",{"Bahrain National Stadium","Beyon Al Dana Amphitheatre","Exhibition World Bahrain"}},
 {"Asia","Kuwait","Kuwait City",29.3759,47.9774,3,"none",{"Jaber Al-Ahmad International Stadium","The Arena Kuwait","Al Shaheed Park"}},
 {"Asia","Oman","Muscat",23.5880,58.3829,4,"none",{"Sultan Qaboos Sports Complex","Oman Convention and Exhibition Centre","Al Mouj Amphitheatre"}},
 {"Asia","Kazakhstan","Almaty",43.2220,76.8512,5,"none",{"Central Stadium Almaty","Almaty Arena","Baluan Sholak Palace"}},
 {"Asia","Georgia","Tbilisi",41.7151,44.8271,4,"none",{"Boris Paichadze Dinamo Arena","Tbilisi Sports Palace","Black Sea Arena"}},
 {"Asia","Armenia","Yerevan",40.1792,44.4991,4,"none",{"Hrazdan Stadium","Karen Demirchyan Complex","Republic Square"}},
 {"Asia","Azerbaijan","Baku",40.4093,49.8671,4,"none",{"Baku Olympic Stadium","Baku Crystal Hall","Heydar Aliyev Arena"}},

 {"Africa","South Africa","Durban",-29.8587,31.0218,2,"none",{"Moses Mabhida Stadium","Kings Park Stadium","Durban ICC Arena"}},
 {"Africa","South Africa","Pretoria",-25.7479,28.2293,2,"none",{"Loftus Versfeld Stadium","SunBet Arena","Supersport Park"}},
 {"Africa","Kenya","Nairobi",-1.2921,36.8219,3,"none",{"Moi International Sports Centre","Nyayo National Stadium","Uhuru Gardens"}},
 {"Africa","Ghana","Accra",5.6037,-0.1870,0,"none",{"Accra Sports Stadium","Black Star Square","Grand Arena Accra"}},
 {"Africa","Ethiopia","Addis Ababa",8.9806,38.7578,3,"none",{"Addis Ababa Stadium","Millennium Hall","Meskel Square"}},
 {"Africa","Tanzania","Dar es Salaam",-6.7924,39.2083,3,"none",{"Benjamin Mkapa Stadium","National Indoor Stadium","Leaders Club Grounds"}},
 {"Africa","Uganda","Kampala",0.3476,32.5825,3,"none",{"Mandela National Stadium","Lugogo Cricket Oval","Kololo Ceremonial Grounds"}},
 {"Africa","Rwanda","Kigali",-1.9441,30.0619,2,"none",{"Amahoro Stadium","BK Arena","Kigali Convention Centre"}},
 {"Africa","Senegal","Dakar",14.7167,-17.4677,0,"none",{"Stade Abdoulaye Wade","Dakar Arena","Monument de la Renaissance Grounds"}},
 {"Africa","Côte d'Ivoire","Abidjan",5.3600,-4.0083,0,"none",{"Stade Alassane Ouattara","Palais de la Culture","Parc des Expositions d'Abidjan"}},
 {"Africa","Tunisia","Tunis",36.8065,10.1815,1,"none",{"Stade Olympique de Radès","Coupole d'El Menzah","Théâtre de Carthage"}},
 {"Africa","Algeria","Algiers",36.7538,3.0588,1,"none",{"Nelson Mandela Stadium","5 July 1962 Stadium","La Coupole d'Alger"}},
 {"Africa","Morocco","Rabat",34.0209,-6.8416,1,"none",{"Prince Moulay Abdellah Stadium","OLM Souissi","Théâtre National Mohammed V"}},
 {"Africa","Morocco","Marrakech",31.6295,-7.9811,1,"none",{"Grand Stade de Marrakech","Palais des Congrès","Place Jemaa el-Fnaa"}},
 {"Africa","Angola","Luanda",-8.8390,13.2894,1,"none",{"Estádio 11 de Novembro","Pavilhão Multiusos do Kilamba","Baía de Luanda"}},
 {"Africa","Mozambique","Maputo",-25.9692,32.5732,2,"none",{"Estádio Nacional do Zimpeto","Pavilhão do Maxaquene","Centro Internacional de Conferências"}},
 {"Africa","Zambia","Lusaka",-15.3875,28.3228,2,"none",{"National Heroes Stadium","Lusaka Showgrounds","Mulungushi Conference Centre"}},
 {"Africa","Zimbabwe","Harare",-17.8252,31.0335,2,"none",{"National Sports Stadium","Harare International Conference Centre","Glamis Arena"}},
 {"Africa","Botswana","Gaborone",-24.6282,25.9231,2,"none",{"Botswana National Stadium","Gaborone International Convention Centre","Royal Aria Stadium"}},
 {"Africa","Namibia","Windhoek",-22.5609,17.0658,2,"none",{"Independence Stadium","Hage Geingob Stadium","Windhoek Show Grounds"}},

 {"Oceania","Australia","Adelaide",-34.9285,138.6007,9.5,"au",{"Adelaide Oval","Adelaide Entertainment Centre","Coopers Stadium"}},
 {"Oceania","Australia","Gold Coast",-28.0167,153.4000,10,"none",{"People First Stadium","Gold Coast Convention Centre","HOTA Outdoor Stage"}},
 {"Oceania","Australia","Newcastle",-32.9283,151.7817,10,"au",{"McDonald Jones Stadium","Newcastle Entertainment Centre","Foreshore Park"}},
 {"Oceania","Australia","Canberra",-35.2809,149.1300,10,"au",{"GIO Stadium Canberra","Manuka Oval","UC Refectory"}},
 {"Oceania","Australia","Hobart",-42.8821,147.3272,10,"au",{"Ninja Stadium","MyState Bank Arena","Royal Tasmanian Botanical Gardens"}},
 {"Oceania","Australia","Darwin",-12.4634,130.8456,9.5,"none",{"TIO Stadium","Darwin Convention Centre","Darwin Amphitheatre"}},
 {"Oceania","New Zealand","Wellington",-41.2866,174.7756,12,"nz",{"Sky Stadium","TSB Arena","Michael Fowler Centre"}},
 {"Oceania","New Zealand","Christchurch",-43.5321,172.6362,12,"nz",{"Apollo Projects Stadium","Wolfbrook Arena","Hagley Park"}},
 {"Oceania","New Zealand","Dunedin",-45.8788,170.5028,12,"nz",{"Forsyth Barr Stadium","Edgar Centre","Dunedin Town Hall"}},
 {"Oceania","Fiji","Suva",-18.1248,178.4501,12,"none",{"HFC Bank Stadium","Vodafone Arena","Albert Park"}},
}
for _,city in ipairs(worldwideCities) do cities[#cities+1]=city end

local function weekday(y,m,d)
 local t={0,3,2,5,0,3,5,1,4,6,2,4}; if m<3 then y=y-1 end
 return (y+math.floor(y/4)-math.floor(y/100)+math.floor(y/400)+t[m]+d)%7
end
local function nthSunday(y,m,n) local first=1+((7-weekday(y,m,1))%7); return first+7*(n-1) end
local function lastSunday(y,m)
 local md={31,28,31,30,31,30,31,31,30,31,30,31}; if m==2 and (y%400==0 or (y%4==0 and y%100~=0)) then md[2]=29 end
 local last=md[m]; return last-((weekday(y,m,last))%7)
end
local function lastWeekday(y,m,wanted)
 local md={31,28,31,30,31,30,31,31,30,31,30,31}; if m==2 and (y%400==0 or (y%4==0 and y%100~=0)) then md[2]=29 end
 local last=md[m]; return last-((weekday(y,m,last)-wanted)%7)
end
local function afterStartBeforeEnd(m,d,sm,sd,em,ed)
 return (m>sm or (m==sm and d>=sd)) and (m<em or (m==em and d<ed))
end
local function dstActive(rule,y,m,d)
 if rule=="us" then return afterStartBeforeEnd(m,d,3,nthSunday(y,3,2),11,nthSunday(y,11,1)) end
 if rule=="eu" then return afterStartBeforeEnd(m,d,3,lastSunday(y,3),10,lastSunday(y,10)) end
 if rule=="au" then return m>10 or m<4 or (m==10 and d>=nthSunday(y,10,1)) or (m==4 and d<nthSunday(y,4,1)) end
 if rule=="nz" then return m>9 or m<4 or (m==9 and d>=lastSunday(y,9)) or (m==4 and d<nthSunday(y,4,1)) end
	if rule=="chile" then return m>9 or m<4 or (m==9 and d>=nthSunday(y,9,1)) or (m==4 and d<nthSunday(y,4,1)) end
	if rule=="israel" then return afterStartBeforeEnd(m,d,3,lastSunday(y,3)-2,10,lastSunday(y,10)) end
	if rule=="egypt" then return afterStartBeforeEnd(m,d,4,lastWeekday(y,4,5),10,lastWeekday(y,10,4)) end
	return false
end
local function offsetString(hours)
 local sign=hours<0 and "-" or "+"; local v=math.abs(hours); local h=math.floor(v); local mins=math.floor((v-h)*60+0.5)
 return string.format("%s%d:%02d",sign,h,mins)
end
local function unique(field,filters)
 local out,seen={},{}; for _,c in ipairs(cities) do
  local pass=true; for k,v in pairs(filters or {}) do if c[k]~=v then pass=false end end
  if pass and not seen[c[field]] then seen[c[field]]=true; out[#out+1]=c[field] end
 end; table.sort(out); return out
end
local function findCity(continent,country,name)
 for _,c in ipairs(cities) do if c[1]==continent and c[2]==country and c[3]==name then return c end end
end

local state={continent="North America",country="USA",city="Dallas, TX",query="",done=false,status="Ready"}
local ui={continentButtons={},countryButtons={},cityButtons={}}
local function localNetworkStatus()
 -- These are the same station-state identifiers displayed in the Network tab.
 local ss=Root().StationSettings
 for _,property in ipairs({'STATUS','SESSIONSTATUS','STATIONSTATUS','NETWORKSTATUS'}) do
  local ok,value=pcall(function() return ss:Get(property) end)
  if ok and value then
   local status=tostring(value)
   if status=='GlobalMaster' or status=='IdleMaster' or status=='Connected' then return status end
  end
 end
 return nil
end
local function configureNtp()
 local tc=Root().StationSettings.TimeConfig
 if not tc then return false end
 -- grandMA3 2.4 stores the Time Server controls on TimeConfig. Read each
 -- property before writing it so unsupported software versions stay silent.
 local function hasProperty(name)
  local ok,value=pcall(function() return tc:Get(name) end)
  return ok and value~=nil
 end
 local serverProperty=hasProperty('SERVERNAME') and 'SERVERNAME' or (hasProperty('TIMESERVERNAME') and 'TIMESERVERNAME') or (hasProperty('NTPSERVERNAME') and 'NTPSERVERNAME') or nil
 local modeProperty=hasProperty('EXTERNTIMESYNCMODE') and 'EXTERNTIMESYNCMODE' or (hasProperty('TIMESYNCMODE') and 'TIMESYNCMODE') or (hasProperty('NTPSYNCMODE') and 'NTPSYNCMODE') or nil
 if not serverProperty or not modeProperty then return false end
 local readOk,serverValue,modeValue=pcall(function() return tc:Get(serverProperty),tc:Get(modeProperty) end)
 if not readOk then return false end
 local serverOk,modeOk=true,true
 if string.lower(tostring(serverValue or ''))~='time.google.com' then
  serverOk=pcall(function() tc:Set(serverProperty,'time.google.com') end)
 end
 if string.lower(tostring(modeValue or ''))~='ntp' then
  modeOk=pcall(function() tc:Set(modeProperty,'NTP') end)
 end
 if not serverOk or not modeOk then return false end
 local verifyOk,serverValue,modeValue=pcall(function() return tc:Get(serverProperty),tc:Get(modeProperty) end)
 return verifyOk and string.lower(tostring(serverValue))=='time.google.com' and string.lower(tostring(modeValue))=='ntp'
end
local function selectedCity() return findCity(state.continent,state.country,state.city) end
local function savedDefault()
 local vars=UserVars(); local continent=GetVar(vars,'TourLocationDefaultContinent'); local country=GetVar(vars,'TourLocationDefaultCountry'); local city=GetVar(vars,'TourLocationDefaultCity')
 if continent and country and city and findCity(tostring(continent),tostring(country),tostring(city)) then return tostring(continent),tostring(country),tostring(city) end
 return 'North America','USA','Dallas, TX'
end
local function offsetFor(c)
 local tc=Root().StationSettings.TimeConfig; local y=tonumber(tc.YEAR); local m=Enums.Month[tostring(tc.MONTH)]+1; local d=tonumber(tc.DAY)
 return offsetString(c[6]+(dstActive(c[7],y,m,d) and 1 or 0))
end
local function dstStatusFor(c)
 if c[7]=='none' then return 'Automatic  •  Not observed' end
 local tc=Root().StationSettings.TimeConfig; local y=tonumber(tc.YEAR); local m=Enums.Month[tostring(tc.MONTH)]+1; local d=tonumber(tc.DAY)
 return dstActive(c[7],y,m,d) and 'Automatic  •  Daylight time active' or 'Automatic  •  Standard time active'
end
local function closeUI() GetFocusDisplay().ScreenOverlay:ClearUIChildren(); state.done=true end
local function addButton(parent,text,clicked,font,selected)
 local b=parent:Append(selected~=nil and 'IndicatorButton' or 'Button'); b.Text=text; b.Font=font or 'Regular20'; b.TextalignmentH='Centre'; b.Textshadow=1; b.HasHover=selected~=nil and 'No' or 'Yes'; b.PluginComponent=myHandle; b.Clicked=clicked
	b.Focus='Never'
 if selected~=nil then b.ColorIndicator=selected and 'Global.PartlySelected' or 'Global.Inactive'; b.BackColor='Global.Inactive'; b.HideFocusFrame='Yes' end
 return b
end

local function ensurePluginColors()
 local globals=Root().ColorTheme.ColorGroups.Global
 local wanted={TourLocationBlack='000000ff',TourLocationWhite='ffffffff',TourLocationAmber='ffb300ff'}; local found={}
 for _,color in ipairs(globals:Children()) do if wanted[color.Name] then color:Set('RGBA',wanted[color.Name]); found[color.Name]=true end end
 for name,rgba in pairs(wanted) do if not found[name] then local color=globals:Acquire(); color:Set('Name',name); color:Set('RGBA',rgba) end end
end

local function setSelected(button,selected)
 if button then button.ColorIndicator=selected and 'Global.PartlySelected' or 'Global.Inactive' end
end
local updateDetails,fillCities,fillCountries

local function render()
 GetFocusDisplay().ScreenOverlay:ClearUIChildren()
	local base=GetFocusDisplay().ScreenOverlay:Append('BaseInput'); ui.base=base; base.Name='TourLocationWindow'; base.H=860; base.W=1180; base.Columns=1; base.Rows=4
 base[1][1].SizePolicy='Fixed'; base[1][1].Size=70; base[1][2].SizePolicy='Fixed'; base[1][2].Size=72; base[1][3].SizePolicy='Stretch'; base[1][4].SizePolicy='Fixed'; base[1][4].Size=82
 base.AutoClose='No'; base.CloseOnEscape='Yes'; base.BackColor='Global.TourLocationBlack'; base.Transparent='No'
 local backdrop=base:Append('DialogFrame'); backdrop.Anchors='0,0,0,3'; backdrop.BackColor='Global.TourLocationBlack'; backdrop.Transparent='No'; backdrop.Enabled='No'
 local title=base:Append('TitleBar'); title.Columns=2; title.Rows=1; title.Anchors='0,0'; title[2][2].SizePolicy='Fixed'; title[2][2].Size=55; title.Texture='corner2'; title.Transparent='No'
	local titleText=title:Append('TitleButton'); titleText.Anchors='0,0'; titleText.Text='Tour Location  •  Worldwide Venue & Session Time'; titleText.Font='Regular24'; titleText.Icon='globe'; titleText.Texture='corner1'
	titleText.Focus='Never'
 local x=title:Append('CloseButton'); x.Anchors='1,0'; x.Texture='corner2'; x.PluginComponent=myHandle; x.Clicked='CloseClicked'; x.Focus='Never'

 local continents=unique(1); local tabs=base:Append('UILayoutGrid'); tabs.Columns=#continents; tabs.Rows=1; tabs.Anchors='0,1'; tabs.Margin='8,6'; tabs.BackColor='Global.TourLocationBlack'; tabs.Transparent='No'
 ui.continentButtons={}; for i,name in ipairs(continents) do local b=addButton(tabs,name,'ContinentClicked','Regular18',name==state.continent); b.Anchors=tostring(i-1)..',0'; b.Name=name; ui.continentButtons[name]=b end

 local body=base:Append('UILayoutGrid'); body.Columns=3; body.Rows=1; body.Anchors='0,2'
 body[2][1].SizePolicy='Fixed'; body[2][1].Size=245
 body[2][2].SizePolicy='Fixed'; body[2][2].Size=335
 body[2][3].SizePolicy='Stretch'; body.Margin='8,4'; body.BackColor='Global.TourLocationBlack'; body.Transparent='No'
 local countryFrame=body:Append('DialogFrame'); countryFrame.Anchors='0,0'; countryFrame.Columns=2; countryFrame.Rows=1; countryFrame[2][2].SizePolicy='Fixed'; countryFrame[2][2].Size=18; countryFrame.BackColor='Global.TourLocationBlack'; countryFrame.Transparent='No'
 local countryBox=countryFrame:Append('ScrollBox'); countryBox.Name='CountryBox'; countryBox.BackColor='Global.TourLocationBlack'; countryBox.Transparent='No'; ui.countryBox=countryBox; local countryBar=countryFrame:Append('ScrollBarV'); countryBar.Anchors='1,0'; countryBar.ScrollTarget='../CountryBox'

 local cityFrame=body:Append('DialogFrame'); cityFrame.Anchors='1,0'; cityFrame.Columns=2; cityFrame.Rows=2; cityFrame[1][1].SizePolicy='Fixed'; cityFrame[1][1].Size=62; cityFrame[1][2].SizePolicy='Stretch'; cityFrame[2][2].SizePolicy='Fixed'; cityFrame[2][2].Size=18; cityFrame.BackColor='Global.TourLocationBlack'; cityFrame.Transparent='No'
	local searchGrid=cityFrame:Append('UILayoutGrid'); searchGrid.Anchors='0,0,1,0'; searchGrid.Columns=3; searchGrid.Rows=1; searchGrid[2][1].SizePolicy='Fixed'; searchGrid[2][1].Size=76; searchGrid[2][2].SizePolicy='Stretch'; searchGrid[2][3].SizePolicy='Fixed'; searchGrid[2][3].Size=70; searchGrid.Margin='4,4'
	local searchLabel=searchGrid:Append('Button'); searchLabel.Anchors='0,0'; searchLabel.Text='SEARCH'; searchLabel.Font='Regular16'; searchLabel.TextColor='Global.TourLocationWhite'; searchLabel.Enabled='Yes'; searchLabel.Interactive='No'; searchLabel.BackColor='Global.TourLocationBlack'
	searchLabel.Focus='Never'
	ui.search=searchGrid:Append('LineEdit'); ui.search.Anchors='1,0'; ui.search.Content=state.query; ui.search.Font='Regular20'; ui.search.TextColor='Global.TourLocationWhite'; ui.search.BackColor='Global.PartlySelected'; ui.search.PluginComponent=myHandle; ui.search.TextChanged='SearchChanged'; ui.search.KeyDown='SearchKeyDown'; ui.search.TextChangeOnEnter=0; ui.search.ShowKeyboardButton='Yes'; ui.search.MaxTextLength=40
	local clearSearch=addButton(searchGrid,'CLEAR','ClearSearchClicked','Regular16'); clearSearch.Anchors='2,0'
 local cityBox=cityFrame:Append('ScrollBox'); cityBox.Name='CityBox'; cityBox.Anchors='0,1'; cityBox.BackColor='Global.TourLocationBlack'; cityBox.Transparent='No'; ui.cityBox=cityBox; local cityBar=cityFrame:Append('ScrollBarV'); cityBar.Anchors='1,1'; cityBar.ScrollTarget='../CityBox'

 local details=body:Append('DialogFrame'); details.Anchors='2,0'; details.Columns=1; details.Rows=2; details[1][1].SizePolicy='Stretch'; details[1][2].SizePolicy='Fixed'; details[1][2].Size=62; details.BackColor='Global.TourLocationBlack'; details.Transparent='No'
	local cards=details:Append('UILayoutGrid'); cards.Anchors='0,0'; cards.Columns=1; cards.Rows=4; cards[1][1].SizePolicy='Fixed'; cards[1][1].Size=94; cards[1][2].SizePolicy='Stretch'; cards[1][3].SizePolicy='Fixed'; cards[1][3].Size=162; cards[1][4].SizePolicy='Fixed'; cards[1][4].Size=104; cards.Margin='8,8'; cards.BackColor='Global.TourLocationBlack'; cards.Transparent='No'
	ui.cityCard=cards:Append('IndicatorButton'); ui.cityCard.Anchors='0,0'; ui.cityCard.Font='Regular24'; ui.cityCard.Enabled='Yes'; ui.cityCard.Interactive='No'; ui.cityCard.ColorIndicator='Global.TourLocationAmber'; ui.cityCard.TextColor='Global.TourLocationWhite'; ui.cityCard.BackColor='Global.PartlySelected'; ui.cityCard.TextalignmentH='Left'; ui.cityCard.Padding='22,10,22,10'
	ui.cityCard.Focus='Never'
	ui.venueCard=cards:Append('IndicatorButton'); ui.venueCard.Anchors='0,1'; ui.venueCard.Font='Regular18'; ui.venueCard.Enabled='Yes'; ui.venueCard.Interactive='No'; ui.venueCard.ColorIndicator='Global.TourLocationAmber'; ui.venueCard.TextColor='Global.TourLocationWhite'; ui.venueCard.BackColor='Global.Inactive'; ui.venueCard.TextalignmentH='Left'; ui.venueCard.TextalignmentV='Top'; ui.venueCard.Padding='24,12,24,10'; ui.venueCard.TextAutoAdjust='No'
	ui.venueCard.Focus='Never'
	ui.locationCard=cards:Append('IndicatorButton'); ui.locationCard.Anchors='0,2'; ui.locationCard.Font='Regular18'; ui.locationCard.Enabled='Yes'; ui.locationCard.Interactive='No'; ui.locationCard.Icon='time'; ui.locationCard.IconAlignmentH='Right'; ui.locationCard.IconAlignmentV='Centre'; ui.locationCard.IconColor='Global.TourLocationAmber'; ui.locationCard.ColorIndicator='Global.TourLocationAmber'; ui.locationCard.TextColor='Global.TourLocationWhite'; ui.locationCard.BackColor='Global.Inactive'; ui.locationCard.TextalignmentH='Left'; ui.locationCard.TextalignmentV='Top'; ui.locationCard.Padding='24,10,72,8'; ui.locationCard.TextAutoAdjust='No'
	ui.locationCard.Focus='Never'
 ui.sessionCard=cards:Append('IndicatorButton'); ui.sessionCard.Anchors='0,3'; ui.sessionCard.Font='Regular18'; ui.sessionCard.Enabled='Yes'; ui.sessionCard.Interactive='No'; ui.sessionCard.Icon='network'; ui.sessionCard.IconAlignmentH='Right'; ui.sessionCard.IconAlignmentV='Centre'; ui.sessionCard.IconColor='Global.TourLocationAmber'; ui.sessionCard.ColorIndicator='Global.TourLocationAmber'; ui.sessionCard.TextColor='Global.TourLocationWhite'; ui.sessionCard.BackColor='Global.Inactive'; ui.sessionCard.TextalignmentH='Left'; ui.sessionCard.TextalignmentV='Top'; ui.sessionCard.Padding='24,12,72,12'; ui.sessionCard.TextAutoAdjust='No'
	ui.sessionCard.Focus='Never'
 local apply=addButton(details,'APPLY SELECTED CITY','ApplyClicked','Regular24'); apply.Anchors='0,1'

 local footer=base:Append('UILayoutGrid'); footer.Columns=4; footer.Rows=1; footer.Anchors='0,3'
 footer[2][1].SizePolicy='Stretch'
 footer[2][2].SizePolicy='Fixed'; footer[2][2].Size=245
 footer[2][3].SizePolicy='Fixed'; footer[2][3].Size=245
 footer[2][4].SizePolicy='Fixed'; footer[2][4].Size=205; footer.Margin='8,8'
 local dc,dk,dy=savedDefault(); ui.defaultHint=footer:Append('Button'); ui.defaultHint.Anchors='0,0'; ui.defaultHint.Text='Default: '..dc..'  →  '..dk..'  →  '..dy; ui.defaultHint.Font='Regular16'; ui.defaultHint.TextColor='Global.TourLocationWhite'; ui.defaultHint.Enabled='Yes'; ui.defaultHint.Interactive='No'; ui.defaultHint.TextalignmentH='Left'
	ui.defaultHint.Focus='Never'
	local saveDefault=addButton(footer,'SET AS DEFAULT','SetDefaultClicked','Regular20'); saveDefault.Anchors='1,0'
	local refresh=addButton(footer,'RESET TO DEFAULT','ResetClicked','Regular20'); refresh.Anchors='2,0'; local close=addButton(footer,'CLOSE','CloseClicked','Regular20'); close.Anchors='3,0'
 fillCountries()
end

updateDetails=function()
 local c=selectedCity(); if not c then return end
 ui.cityCard.Text=c[3]..'\n'..c[2]..'  •  '..c[1]
	ui.venueCard.Text='VENUES\n•  '..table.concat(c[8],'\n•  ')
	ui.locationCard.Text='LOCATION & LOCAL TIME\nLatitude     '..c[4]..'\nLongitude  '..c[5]..'\nUTC offset  '..offsetFor(c)..'\nDST  '..dstStatusFor(c)
 ui.sessionCard.Text='SESSION STATUS\n\nCurrent offset  '..tostring(Root().StationSettings.TimeConfig.TIMEZONE)..'\n'..state.status
end
fillCities=function()
 ui.cityBox:ClearUIChildren(); ui.cityButtons={}; local names=unique(3,{[1]=state.continent,[2]=state.country}); local filtered={}; local q=string.lower(state.query or '')
 for _,name in ipairs(names) do if q=='' or string.find(string.lower(name),q,1,true) then filtered[#filtered+1]=name end end
	state.filteredCities=filtered
 for i,name in ipairs(filtered) do local b=addButton(ui.cityBox,name,'CityClicked','Regular20',name==state.city); b.Name=name; b.X=4; b.Y=(i-1)*58; b.W=305; b.H=54; b.Anchors='0,0'; ui.cityButtons[name]=b end
 if #filtered==0 then local none=ui.cityBox:Append('Button'); none.Text='No matching cities'; none.Font='Regular20'; none.TextColor='Global.TourLocationWhite'; none.Enabled='No'; none.X=4; none.Y=0; none.W=305; none.H=54; none.Anchors='0,0' end
 updateDetails()
end
fillCountries=function()
 ui.countryBox:ClearUIChildren(); ui.countryButtons={}; local names=unique(2,{[1]=state.continent})
 for i,name in ipairs(names) do local b=addButton(ui.countryBox,name,'CountryClicked','Regular20',name==state.country); b.Name=name; b.X=4; b.Y=(i-1)*58; b.W=215; b.H=54; b.Anchors='0,0'; ui.countryButtons[name]=b end
 fillCities()
end

signalTable.ContinentClicked=function(caller)
 setSelected(ui.continentButtons[state.continent],false); state.continent=caller.Name; setSelected(ui.continentButtons[state.continent],true); local countries=unique(2,{[1]=state.continent}); state.country=(state.continent=='North America' and 'USA') or countries[1]; local list=unique(3,{[1]=state.continent,[2]=state.country}); state.city=list[1]; state.query=''; state.keyboardIndex=0; ui.search.Content=''; state.status='Ready'; fillCountries()
end
signalTable.CountryClicked=function(caller) setSelected(ui.countryButtons[state.country],false); state.country=caller.Name; setSelected(ui.countryButtons[state.country],true); local list=unique(3,{[1]=state.continent,[2]=state.country}); state.city=list[1]; state.query=''; state.keyboardIndex=0; ui.search.Content=''; state.status='Ready'; fillCities() end
signalTable.CityClicked=function(caller) setSelected(ui.cityButtons[state.city],false); state.city=caller.Name; setSelected(ui.cityButtons[state.city],true); state.status='Ready'; updateDetails() end
signalTable.SearchChanged=function(caller) state.query=tostring(caller.Content or ''); state.keyboardIndex=0; caller.BackColor='Global.Inactive'; fillCities() end
signalTable.SearchKeyDown=function(caller,dummy,keyCode)
 local list=state.filteredCities or {}; if #list==0 then return end
 local index=state.keyboardIndex or 0
 if keyCode==Enums.KeyboardCodes.Down then index=math.min(index+1,#list)
 elseif keyCode==Enums.KeyboardCodes.Up then index=math.max(index-1,1)
 elseif keyCode==Enums.KeyboardCodes.Enter then
  if index<1 then index=1 end
  setSelected(ui.cityButtons[state.city],false); state.keyboardIndex=index; state.city=list[index]; setSelected(ui.cityButtons[state.city],true); updateDetails(); signalTable.ApplyClicked(); return true
 else return false end
 setSelected(ui.cityButtons[state.city],false); state.keyboardIndex=index; state.city=list[index]; setSelected(ui.cityButtons[state.city],true); state.status='Selected with keyboard'; updateDetails()
	state.refocusSearch=true
	return true
end
signalTable.ClearSearchClicked=function() state.query=''; state.keyboardIndex=0; ui.search.Content=''; fillCities() end
signalTable.SetDefaultClicked=function()
 local vars=UserVars(); SetVar(vars,'TourLocationDefaultContinent',state.continent); SetVar(vars,'TourLocationDefaultCountry',state.country); SetVar(vars,'TourLocationDefaultCity',state.city); state.status='Default saved'; ui.defaultHint.Text='Default: '..state.continent..'  →  '..state.country..'  →  '..state.city; updateDetails()
end
signalTable.ResetClicked=function() local continent,country,city=savedDefault(); setSelected(ui.continentButtons[state.continent],false); state.continent=continent; state.country=country; state.city=city; state.query=''; state.keyboardIndex=0; ui.search.Content=''; state.status='Reset to saved default'; setSelected(ui.continentButtons[state.continent],true); fillCountries() end
signalTable.CloseClicked=function() closeUI() end
signalTable.ApplyClicked=function()
 local networkStatus=localNetworkStatus()
 if networkStatus=='Connected' then
  state.status='Browse only  •  Connected station'; updateDetails()
  MessageBox({title='GlobalMaster Required',icon='network',backColor='Global.PartlySelected',message='Network status: Connected\n\nTour Location must be applied from the GlobalMaster.',commands={{value=1,name='OK'}}})
  return
 end
 local c=selectedCity(); if not c then return end; local tc=Root().StationSettings.TimeConfig; local old={tostring(tc.TIMEZONE),tostring(tc.LONGITUDE),tostring(tc.LATITUDE)}; local offset=offsetFor(c)
 local ok,err=pcall(function() tc:Set('TIMEZONE',offset); tc:Set('LONGITUDE',tostring(c[5])); tc:Set('LATITUDE',tostring(c[4])) end)
 if not ok then pcall(function() tc:Set('TIMEZONE',old[1]);tc:Set('LONGITUDE',old[2]);tc:Set('LATITUDE',old[3]) end); state.status='ERROR: '..tostring(err); updateDetails(); return end
 closeUI()
	MessageBox({title='Tour Location Confirmed',icon='globe',backColor='Global.PartlySelected',message=c[3]..'\n\nTimezone  '..tostring(tc.TIMEZONE)..'\nLatitude  '..tostring(tc.LATITUDE)..'\nLongitude  '..tostring(tc.LONGITUDE),commands={{value=1,name='OK'}}})
end

local function main()
	ensureUtilityTag()
	bindPluginAppearance()
	local continent,country,city=savedDefault(); local networkStatus=localNetworkStatus(); local ntpReady=configureNtp(); local startupStatus=networkStatus=='Connected' and ('Browse only  •  Connected station'..(ntpReady and '  •  NTP  •  time.google.com' or '')) or (ntpReady and 'NTP  •  time.google.com' or (networkStatus or 'Ready')); state={continent=continent,country=country,city=city,query='',keyboardIndex=0,filteredCities={},refocusSearch=false,done=false,status=startupStatus}; ui={continentButtons={},countryButtons={},cityButtons={}}; ensurePluginColors(); render()
	-- Wait until the dialog is actually drawn before handing keyboard focus to
	-- its first editable control. FindBestFocus requires the dialog handle.
	ui.base:WaitInit()
	FindBestFocus(ui.base)
	while not state.done do
	 coroutine.yield(0.1)
	 if state.done then break end
	 if ui.search then
	  local valid,current=pcall(function() return tostring(ui.search.Content or '') end)
	  if not valid then state.done=true; break end
	  if state.refocusSearch then state.refocusSearch=false; pcall(function() FindBestFocus(ui.search) end) end
	  if current~=state.query then state.query=current; state.keyboardIndex=0; fillCities() end
	 end
	end
end
return main
