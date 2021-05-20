proc format;
value $pregout
0 = '0. missing or invalid combination'
1 = '1. Preterm-Acceptable wght for GA'
2 = '2. Preterm-Small wght for GA'
4 = '4. Term-Acceptable wght for GA'
5 = '5. Term-Small wght for GA'
7 = '7. PostTerm-Acceptable wght for GA'
8 = '8. PostTerm-Small wght for GA';
value bin
0 = "No"
1 = "Yes";
value $bin
0 = "No"
1 = "Yes";
run;


proc format;
      value mrace5c
      1="Non-Hispanic_White"
      2="Non-Hispanic_Black"
      3="Hispanic"
      4="Asian/Pacific_Islander"
      5="Other/Missing"
      ;
      value meduc4c
      1="High_school_or_less"
      2="Some_college"
      3="Completed_college"
      4="Missing"
	  ;
      value delpayer3c
      1="Government"
      2="Private"
      3="Other/Missing"
      ;
	  value mage_cat
	  1="<20"
	  2="20-<30"
	  3="30-<40"
	  4="=>40"
	  5="Missing"
	  ;
	  value hyp
	  0="No"
	  1="Yes"
	  ;
	  value dia
	  0="No"
	  1="Yes"
	  ;
	  value parcat
	  1="1"
	  2="2"
	  3="3"
	  4="4"
	  5=">=5"
	  ;
	  value gest_cat
	  1 = "20-30_weeks"
	  2 = "31-36_weeks"
	  3 = "37-45_weeks"
	  ;
	  value bin
	  0 = "No"
	  1 = "Yes";	
	  value $bin
	  0 = "No"
	  1 = "Yes";
	  value fdcat
	  0 = "Not_Otherwise_Specified"
	  1 = "Umbilical_Cord_Anomalies"
	  2 = "Placental_Conditions"
	  3 = "Obstetric_Complications"
	  4 = "Infections"
	  5 = "Fetal_major_structural_malformations_and/or_genetic_abnormalities"
	  6 = "Maternal_Medical_Conditions"
	  7 = "Hypertensive_Disorders"
	  8 = "Other"
	  ;
	value hyp_cat
	0 = "No_gestational_hypertension"
	1 = "Gestational_hypertension"
	2 = "Preeclampsia_or_eclampsia"
	;
	value complication
	0 = "No_Complications"
	1 = "Any_Complication"
	;
	value bateman_cat
	0 = "0-2"
	1 = "3-4"
	2 = "5-6"
	3 = "7-8"
	4 = "9-10"
	5 = ">10"
	;
	value usborn
	 2="Missing"
     1="US-born"
	 0= "Foreign-Born"
	 ;
run;
