# Providing supplemental forcing

There are certain times that the user wants to combine atmospheric analyses from reanalysis products or other models with a separate analysis of precipitation (e.g. a gridded gauge product, radar QPE, nowcasts, satellite QPE, etc). To enable such behaviour, the user can change the forcing option to 6 to use supplementary precipiation files.

```
&WRF_HYDRO_OFFLINE

! Specification of forcing data:  1=HRLDAS-hr format, 2=HRLDAS-min format, 3=WRF,
!    4=Idealized, 5=Ideal w/ Spec.Precip., 6=HRLDAS-hrl y fomat w/ Spec. Precip,
FORC_TYP = 6
```

If the FORC_TYP is set to 6, the model reads in the meteorological forcing data fields on each hour and then holds those values constant for the entire hour. Precipitation can be read in more frequently based on the user-specified FORCING_TIMESTEP namelist parameter in the namelist.hrldas file. For example, the user can have ‘hourly’ meteorology with ‘5-minute’ precipitation analyses. These supplementary precipitation files are netCDF files containing a single gridded field with either the name “precip” and units of mm or “precip_rate” with unit a unit of mm/s. When using this forcing type, the WRF-Hydro system will look for a new precipitation input file based on the user-specified FORCING_TIMESTEP namelist option set in the namelist.hrldas file. Scripts provided on the WRF-Hydro website will generate files in this format (specifically the MRMS regridding scripts). Here, we have prepared Stage IV data as the supplementary precipitation forcing. And it is located in the test case supplemental directory. 

## Setting up the run directory
The only change required for this experiment is to change the namelist.hrldas. We can copy the template run directory for starter. 
```
cp -r ~/wrf-hydro-training/output/lesson4/run_gridded_template ~/wrf-hydro-training/output/lesson4/supplemental_forcing
```
## Change the namelist and FORCING
We need to change the forcing type from 1 to 6, to be able to enable using the supplemental forcing. 

```
&WRF_HYDRO_OFFLINE

! Specification of forcing data:  1=HRLDAS-hr format, 2=HRLDAS-min format, 3=WRF,
!    4=Idealized, 5=Ideal w/ Spec.Precip., 6=HRLDAS-hrl y fomat w/ Spec. Precip,
FORC_TYP = 6
```

And then you need to make symbolic links to the supplemental forcing

```bash
ln -s ~/wrf-hydro-training/example_case/supplemental/regridding_stageIV/20110* ~/wrf-hydro-training/output/lesson4/supplemental_forcing/FORCING/
```

Let take a look at the forcing diretory.

```bash
ls ~/wrf-hydro-training/output/lesson4/supplemental_forcing/FORCING/
```

Now you see two files per each hour, the *PRECIP_FORCING* will be used for the preciptation data and *LDASIN_DOMAIN* would be used for all other forcings. 

## Run the simulation
Now that we have constructed our simulation directory, we can run our simulation.

```bash
cd ~/wrf-hydro-training/output/lesson4/supplemental_forcing
mpirun -np 4 ./wrf_hydro.exe >> run.log 2>&1
```
## Comparng NLDAS versus StageIV precipitation forced simulation

Here we plot the simulated streamflow from the two runs forced by NLDAS and Stage IV precipitation data. 
```R
# Plot the streamflow simulation with NLDAS versus StageIV forcing
library(foreach)

# read the obs files
obs <- read.csv("~/wrf-hydro-training/example_case/USGS_obs.csv")
metadata <- read.csv("~/wrf-hydro-training/example_case/Gridded/croton_frxst_pts.csv")
obs <- merge(obs,  metadata, by.x = "site_no", by.y = "Site_No")
names(obs) <- c("site_no", "time", "streamflow", "feature_id", "LON", "LAT", "STATION")

# list the CHANOBS files for the simulation forced by StageIV
chrtFiles <- list.files("/glade2/scratch2/arezoo/wrf-hydro-training/output/lesson4/supplemental_forcing",
                        glob2rx("*CHANOBS*"), full.names = TRUE)
stageIV <- foreach(f = chrtFiles, .combine = rbind.data.frame) %do% {
  a <- rwrfhydro::GetNcdfFile(f, variables = c("feature_id", "streamflow"), quiet = TRUE)
  a$time <- as.POSIXct(substr(basename(f), 1, 12), format = "%Y%m%d%H%M", tz = "UTC")
  return(a)
}

# list the CHANOBS files for the simulation forced by NLDAS
chrtFiles <- list.files("/glade2/scratch2/arezoo/wrf-hydro-training/output/lesson4/run_gridded_baseline/",
                        glob2rx("*CHANOBS*"), full.names = TRUE)

NLDAS <- foreach(f = chrtFiles, .combine = rbind.data.frame) %do% {
  a <- rwrfhydro::GetNcdfFile(f, variables = c("feature_id", "streamflow"), quiet = TRUE)
  a$time <- as.POSIXct(substr(basename(f), 1, 12), format = "%Y%m%d%H%M", tz = "UTC")
  return(a)
}

# concatenate the two run and plot it
stageIV$run <- "StageIV forced"
NLDAS$run <- "NLDAS foced"
obs$run <- "Observation"

merged <- rbind(stageIV, NLDAS, obs[, names(NLDAS)])

library(ggplot2)
ggplot(data = merged) + geom_line(aes(time, streamflow, color = run)) + facet_wrap(~feature_id)
```
Here, you can see the huge impact of precipitation choice. Let s plot the precipitation fields to see how the two are different. 

```R
filesLDASIN <- list.files("~/wrf-hydro-training/output/lesson4/supplemental_forcing/FORCING",
                          pattern = glob2rx("*LDASIN*"), full.names = TRUE)

filesPRECIP <- list.files("~/wrf-hydro-training/output/lesson4/supplemental_forcing/FORCING",
                          pattern = glob2rx("*PRECIP*"), full.names = TRUE)

df <- foreach(i=60:65, .combine = rbind.data.frame) %do% {
  
  nldas <- rwrfhydro::ncdump(filesLDASIN[i], "RAINRATE", quiet = TRUE)
  st4   <- rwrfhydro::ncdump(filesPRECIP[i], "precip_rate", quiet = TRUE)
  
  df <- rbind(data.frame(p = c(nldas),
                         j = rep(1:nrow(nldas),ncol(nldas)),
                         i = rep(1:ncol(nldas),each = nrow(nldas)),
                         run = "NLDAS",
                         time=substr(basename(filesLDASIN[i]), 1, 10)),
              data.frame(p = c(st4),
                         j = rep(1:nrow(st4),ncol(st4)),
                         i = rep(1:ncol(st4),each = nrow(st4)),
                         run = "ST4",
                         time=substr(basename(filesPRECIP[i]), 1, 10)))
  return(df)
}

ggplot(df)+geom_raster(aes(x=i, y=j, fill = p*3600))+facet_grid(time~run)+
  scale_fill_continuous(low = "white", high= "blue")

```
As seen above the spatial pattern of the two forcing are very different. Stage IV peaks on the south part of the basin and does not contribute to the streamflow generation. 