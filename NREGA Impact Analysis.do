cd "/Users/ayaan_siddiqui/Desktop/Spring2025Research"
import delimited nrega_rollout_phases.csv, clear
save nrega_rollout_phases.dta, replace
import delimited coc_block1.csv, clear 
rename dist_code censuscode
* NOTE: "censuscode" in the nrega_rollout_phases and "dist_code" in coc_block1 seem to be the same variable, so I renamed "dist_code" as "censuscode."
save coc_block1.dta, replace

use coc_block1.dta, clear
sort censuscode
merge m:1 censuscode using nrega_rollout_phases.dta
* NOTE: Used the renamed variable "censuscode" to merge the two datasets.
drop st_nm
drop district district_unique
* NOTE: Dropped variables "st_nm," "district," and "district_unique" as they contained duplicate information from the master dataset.

gen start_year = .
replace start_year = 2005 if phase == 1
replace start_year = 2006 if phase == 2
replace start_year = 2007 if phase == 3
gen had_nrega = (start_year <= year)
* NOTE: The variable "start_year" records what agricultural year NREGA was implemented. The "had_nrega" variable checks whether each observation had NREGA based on the agricultural year of observation and returns 1 for true and 0 for false.

egen p25_famlab = pctile(famlab_rs), p(25)
egen p75_famlab = pctile(famlab_rs), p(75)
egen p25_tehsil = pctile(tehsilcultivator), p(25)
egen p75_tehsil = pctile(tehsilcultivator), p(75)
gen iqr_famlab = p75_famlab - p25_famlab
gen iqr_tehsil = p75_tehsil - p25_tehsil
gen lower_famlab = p25_famlab - 1.5 * iqr_famlab
gen upper_famlab = p75_famlab + 1.5 * iqr_famlab
gen lower_tehsil = p25_tehsil - 1.5 * iqr_tehsil
gen upper_tehsil = p75_tehsil + 1.5 * iqr_tehsil
drop if famlab_rs < lower_famlab | famlab_rs > upper_famlab
drop if tehsilcultivator < lower_tehsil | tehsilcultivator > upper_tehsil
drop p25_famlab p75_famlab p25_tehsil p75_tehsil iqr_famlab iqr_tehsil /// 
	lower_famlab upper_famlab lower_tehsil upper_tehsil
* NOTE: Removes outliers from "famlab_rs" and "tehsilcultivator" by calculating the 25th and 75th percentiles, finding the IQR, defining outlier thresholds as 1.5 times the IQR beyond these percentiles, and dropping values outside this range.
	
histogram famlab_rs, bin(30) percent title("Density of famlab_rs") xlabel(, grid)
histogram tehsilcultivator, bin(30) percent title("Density of tehsilcultivator") xlabel(, grid)

ssc install reghdfe
ssc install ftools
reghdfe famlab_rs had_nrega, absorb(tehsilcultivator year) cluster(tehsilcultivator)
* NOTE: The above regression examines the impact of NREGA participation on farmland labor spending, controlling for farmer and time fixed effects. 
* The results show that NREGA participation reduces labor spending by 316.6 units, which is quite a large decrease. 
* Additionally, the "tehsilcultivator" fixed effect absorbs all differences across regions while the "year" fixed effect controls for time-specific external factors.

egen p25_atchdlab = pctile(atchdlab_rs), p(25)
egen p75_atchdlab = pctile(atchdlab_rs), p(75)
egen p25_casuallab = pctile(casuallab_rs), p(25)
egen p75_casuallab = pctile(casuallab_rs), p(75)
gen iqr_atchdlab = p75_atchdlab - p25_atchdlab
gen iqr_casuallab = p75_casuallab - p25_casuallab
gen lower_atchdlab = p25_atchdlab - 1.5 * iqr_atchdlab
gen upper_atchdlab = p75_atchdlab + 1.5 * iqr_atchdlab
gen lower_casuallab = p25_casuallab - 1.5 * iqr_casuallab
gen upper_casuallab = p75_casuallab + 1.5 * iqr_casuallab
drop if atchdlab_rs < lower_atchdlab | atchdlab_rs > upper_atchdlab
drop if casuallab_rs < lower_casuallab | casuallab_rs > upper_casuallab
drop p25_casuallab p75_casuallab iqr_casuallab lower_casuallab upper_casuallab
* NOTE: Used the IQR method again for variables "atchdlab_rs" and "casuallab_rs."

gen log_atchdlab = log(atchdlab_rs)
histogram log_atchdlab, bin(30) percent title("Log-Transformed Density of atchdlab_rs") xlabel(, grid)
histogram casuallab_rs, bin(30) percent title("Density of casuallab_rs") xlabel(, grid)

gen total_lab_costs = famlab_rs + atchdlab_rs + casuallab_rs
gen total_lab_costs_2005 = .

bysort farmerid (year): replace total_lab_costs_2005 = total_lab_costs if year == 2005
bysort farmerid (year total_lab_costs): replace total_lab_costs_2005 = ///  
total_lab_costs_2005[_n-1] if missing(total_lab_costs_2005)
gen norm_lab_costs = total_lab_costs / total_lab_costs_2005
* NOTE: Each farm's total labor costs in 2005 are assigned to the "total_lab_costs_2005" variable. 
* If this value is missing for later years, it is filled in using the previous year's value for the same farm.
* The "norm_lab_costs" variable divides each year's total labor cost by the 2005 value, showing labor costs relative to the 2005 baseline.

keep if (phase == 2 | phase == 3) & (year == 2005 | year == 2006)
gen treated = (phase == 2)
gen post = (year == 2006)
gen did = treated * post

reghdfe norm_lab_costs did, absorb(farmerid year) cluster(farmerid)
