import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Controllers/ReportScan/scan_report_controller.dart';
import '../../consts/colors.dart';

// ─────────────────────────────────────────────
// DUMMY DATA — replace with real API call later
// ─────────────────────────────────────────────
// const String _dummyApiContent = '''
// {
//   "overall_health_score": 70,
//   "overall_status": "Needs Attention",
//   "doctor_consultation_recommended": true,
//   "emergency_attention_needed": false,
//   "key_findings": [
//     "Uric Acid borderline high",
//     "Triglycerides high",
//     "Low HDL Cholesterol",
//     "Globulin borderline high",
//     "GFR mildly reduced"
//   ],
//   "parameters": [
//     {
//       "test_name": "Urea",
//       "value": "19",
//       "unit": "mg/dl",
//       "reference_range": "13 - 43",
//       "status": "NORMAL",
//       "severity_score": 15,
//       "status_color": "green",
//       "hex_code": "#22C55E",
//       "clinical_meaning": "Normal urea levels indicate good kidney function.",
//       "possible_causes": [],
//       "recommended_actions": [],
//       "diet_recommendations": [],
//       "exercise_recommendations": []
//     },
//     {
//       "test_name": "Creatinine",
//       "value": "1.12",
//       "unit": "mg/dl",
//       "reference_range": "0.7 - 1.3",
//       "status": "NORMAL",
//       "severity_score": 15,
//       "status_color": "green",
//       "hex_code": "#22C55E",
//       "clinical_meaning": "Normal creatinine levels indicate healthy kidney function.",
//       "possible_causes": [],
//       "recommended_actions": [],
//       "diet_recommendations": [],
//       "exercise_recommendations": []
//     },
//     {
//       "test_name": "Uric Acid",
//       "value": "7",
//       "unit": "mg/dl",
//       "reference_range": "3.6 - 7.0",
//       "status": "HIGH",
//       "severity_score": 61,
//       "status_color": "orange",
//       "hex_code": "#F97316",
//       "clinical_meaning": "Slightly elevated uric acid may indicate risk of gout.",
//       "possible_causes": ["Diet high in purines", "Dehydration", "Kidney dysfunction"],
//       "recommended_actions": ["Reduce purine-rich foods like red meat and seafood.", "Stay well-hydrated."],
//       "diet_recommendations": ["Increase water intake", "Limit red meat and shellfish"],
//       "exercise_recommendations": ["Walking", "Moderate aerobic exercise"]
//     },
//     {
//       "test_name": "Estimated GFR",
//       "value": "80",
//       "unit": "mL/min/1.73 m2",
//       "reference_range": "> 90",
//       "status": "LOW",
//       "severity_score": 41,
//       "status_color": "orange",
//       "hex_code": "#F97316",
//       "clinical_meaning": "Mildly reduced kidney function.",
//       "possible_causes": ["Chronic kidney disease", "Dehydration", "Age-related changes"],
//       "recommended_actions": ["Follow up with more tests", "Monitor kidney function regularly"],
//       "diet_recommendations": ["Eat a balanced diet", "Limit sodium intake"],
//       "exercise_recommendations": ["Gentle activities like yoga", "Avoid excessive high-impact exercises"]
//     },
//     {
//       "test_name": "Total Cholesterol",
//       "value": "172",
//       "unit": "mg/dl",
//       "reference_range": "140 - 200",
//       "status": "NORMAL",
//       "severity_score": 15,
//       "status_color": "green",
//       "hex_code": "#22C55E",
//       "clinical_meaning": "Normal cholesterol levels are good for heart health.",
//       "possible_causes": [],
//       "recommended_actions": [],
//       "diet_recommendations": [],
//       "exercise_recommendations": []
//     },
//     {
//       "test_name": "Triglycerides",
//       "value": "222",
//       "unit": "mg/dl",
//       "reference_range": "< 150",
//       "status": "HIGH",
//       "severity_score": 67,
//       "status_color": "orange",
//       "hex_code": "#F97316",
//       "clinical_meaning": "High triglycerides can increase heart disease risk.",
//       "possible_causes": ["Obesity", "Lack of physical activity", "High-carb diet"],
//       "recommended_actions": ["Improve diet", "Increase physical activity"],
//       "diet_recommendations": ["Reduce sugar intake", "Increase omega-3 fatty acids"],
//       "exercise_recommendations": ["At least 150 minutes of moderate exercise per week"]
//     },
//     {
//       "test_name": "HDL Cholesterol",
//       "value": "32.7",
//       "unit": "mg/dl",
//       "reference_range": "35.2 - 79.5",
//       "status": "LOW",
//       "severity_score": 61,
//       "status_color": "orange",
//       "hex_code": "#F97316",
//       "clinical_meaning": "Low HDL is associated with increased heart disease risk.",
//       "possible_causes": ["Unhealthy diet", "Sedentary lifestyle", "Smoking"],
//       "recommended_actions": ["Increase healthy fats", "Regular aerobic activity"],
//       "diet_recommendations": ["Include avocados, nuts, and olive oil"],
//       "exercise_recommendations": ["30 min brisk walk daily", "Cycling or swimming"]
//     }
//   ]
// }
// ''';

const String _dummyApiContent = "{\"overall_health_score\":86,\"overall_status\":\"Good\",\"doctor_consultation_recommended\":true,\"urgent_medical_review_needed\":false,\"emergency_message\":\"\",\"key_findings\":[\"Your Iron is lower than normal (31.00 \\u00B5g/dL). Low iron levels may indicate iron deficiency.\",\"Your Transferrin Saturation is lower than normal (9.14 %). Low transferrin saturation may indicate iron deficiency.\",\"Your Lymphocytes is lower than normal (6.40 %). Low lymphocyte percentage may indicate immune suppression.\",\"Your Alkaline Phosphatase (ALP) is higher than normal (129.00 U/L). Elevated levels may indicate liver or bone issues.\",\"Your Bilirubin Direct is higher than normal (0.33 mg/dL). Elevated direct bilirubin may indicate liver issues.\",\"Your Amylase is higher than normal (125.00 U/L). Elevated amylase may indicate pancreatitis.\"],\"parser_learning\":{\"parameter_aliases\":[{\"standard_name\":\"Bilirubin Total\",\"aliases\":[\"Bilirubin Total\"]},{\"standard_name\":\"Alkaline Phosphatase\",\"aliases\":[\"Alkaline Phosphatase (ALP)\"]},{\"standard_name\":\"HbA1c\",\"aliases\":[\"HbA1c\"]},{\"standard_name\":\"Amylase\",\"aliases\":[\"Amylase\"]}],\"unit_conversions\":[],\"noise_patterns\":[\"Report Status\",\"Collected\",\"Reported\",\"Lab No.\",\"Ref By\",\"A/c Status Final\",\"Collected at\",\"Processed at\",\"Plot No.\",\"Test Report\",\"Note\",\"Interpretation\",\"Advise\",\"Comment\"],\"unknown_params\":[]},\"parameters\":[{\"test_name\":\"Creatinine\",\"value\":\"1.10\",\"unit\":\"mg/dL\",\"reference_range\":\"0.70 - 1.30\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal kidney function.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"GFR Estimated\",\"value\":\"86\",\"unit\":\"mL/min/1.73m2\",\"reference_range\":\"\\u003E59\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal kidney filtration rate.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Urea\",\"value\":\"29.00\",\"unit\":\"mg/dL\",\"reference_range\":\"13.00 - 43.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal urea levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Urea Nitrogen Blood\",\"value\":\"13.54\",\"unit\":\"mg/dL\",\"reference_range\":\"6.00 - 20.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal blood urea nitrogen levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Uric Acid\",\"value\":\"6.20\",\"unit\":\"mg/dL\",\"reference_range\":\"3.50 - 7.20\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal uric acid levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"AST (SGOT)\",\"value\":\"22.0\",\"unit\":\"U/L\",\"reference_range\":\"15.00 - 40.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal liver enzyme levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"ALT (SGPT)\",\"value\":\"25.0\",\"unit\":\"U/L\",\"reference_range\":\"10.00 - 49.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal liver enzyme levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"AST:ALT Ratio\",\"value\":\"0.88\",\"unit\":\"\",\"reference_range\":\"\\u003C1.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal liver function.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"GGTP\",\"value\":\"24.0\",\"unit\":\"U/L\",\"reference_range\":\"0 - 73\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal liver function.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Alkaline Phosphatase (ALP)\",\"value\":\"129.00\",\"unit\":\"U/L\",\"reference_range\":\"30.00 - 120.00\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Elevated levels may indicate liver or bone issues.\",\"recommended_actions\":[\"Consider further evaluation of liver function.\",\"Monitor for symptoms of liver disease.\",\"Consult a healthcare provider for further testing.\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Bilirubin Total\",\"value\":\"0.99\",\"unit\":\"mg/dL\",\"reference_range\":\"0.30 - 1.20\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal bilirubin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Bilirubin Direct\",\"value\":\"0.33\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C0.3\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Elevated direct bilirubin may indicate liver issues.\",\"recommended_actions\":[\"Consider further evaluation of liver function.\",\"Monitor for symptoms of liver disease.\",\"Consult a healthcare provider for further testing.\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Bilirubin Indirect\",\"value\":\"0.66\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C1.10\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal indirect bilirubin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Total Protein\",\"value\":\"7.00\",\"unit\":\"g/dL\",\"reference_range\":\"5.70 - 8.20\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal protein levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Albumin\",\"value\":\"4.57\",\"unit\":\"g/dL\",\"reference_range\":\"3.20 - 4.80\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal albumin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Globulin(Calculated)\",\"value\":\"2.43\",\"unit\":\"gm/dL\",\"reference_range\":\"2.0 - 3.5\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal globulin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"A : G Ratio\",\"value\":\"1.88\",\"unit\":\"\",\"reference_range\":\"0.90 - 2.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal albumin to globulin ratio.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Calcium, Total\",\"value\":\"9.30\",\"unit\":\"mg/dL\",\"reference_range\":\"8.70 - 10.40\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal calcium levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Phosphorus\",\"value\":\"2.80\",\"unit\":\"mg/dL\",\"reference_range\":\"2.40 - 5.10\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal phosphorus levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Sodium\",\"value\":\"140.00\",\"unit\":\"mEq/L\",\"reference_range\":\"136.00 - 145.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal sodium levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Potassium\",\"value\":\"4.53\",\"unit\":\"mEq/L\",\"reference_range\":\"3.50 - 5.10\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal potassium levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Chloride\",\"value\":\"104.00\",\"unit\":\"mEq/L\",\"reference_range\":\"98.00 - 107.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal chloride levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Cholesterol, Total\",\"value\":\"158.00\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C200.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal total cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Triglycerides\",\"value\":\"102.00\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C150.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal triglyceride levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"HDL Cholesterol\",\"value\":\"45.30\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003E40.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal HDL cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"LDL Cholesterol, Calculated\",\"value\":\"92.30\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C100.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal LDL cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"VLDL Cholesterol,Calculated\",\"value\":\"20.40\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C30.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal VLDL cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Non-HDL Cholesterol\",\"value\":\"113\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C130\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal non-HDL cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Glucose Fasting\",\"value\":\"83.00\",\"unit\":\"mg/dL\",\"reference_range\":\"70 - 100\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal fasting glucose levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Vitamin B12; Cyanocobalamin\",\"value\":\"303.00\",\"unit\":\"pg/mL\",\"reference_range\":\"211.00 - 911.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal vitamin B12 levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Vitamin D, 25 Hydroxy\",\"value\":\"94.88\",\"unit\":\"nmol/L\",\"reference_range\":\"75.00 - 250.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal vitamin D levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"T3, Total\",\"value\":\"1.56\",\"unit\":\"ng/mL\",\"reference_range\":\"0.60 - 1.81\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal T3 levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"T4, Total\",\"value\":\"8.30\",\"unit\":\"\\u00B5g/dL\",\"reference_range\":\"4.50 - 11.60\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal T4 levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"TSH\",\"value\":\"0.87\",\"unit\":\"\\u00B5IU/mL\",\"reference_range\":\"0.550 - 4.780\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal TSH levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Amylase\",\"value\":\"125.00\",\"unit\":\"U/L\",\"reference_range\":\"30.00 - 118.00\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Elevated amylase may indicate pancreatitis.\",\"recommended_actions\":[\"Consider further evaluation of pancreatic function.\",\"Monitor for symptoms of pancreatitis.\",\"Consult a healthcare provider for further testing.\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"HbA1c\",\"value\":\"5.7\",\"unit\":\"%\",\"reference_range\":\"4.00 - 5.60\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Borderline high HbA1c suggests risk for diabetes.\",\"recommended_actions\":[\"Consider lifestyle changes to improve blood sugar control.\",\"Monitor blood glucose levels regularly.\",\"Consult a healthcare provider for further evaluation.\"],\"diet_recommendations\":[\"Eat iron-rich foods: spinach, lentils, beans, red meat\",\"Include Vitamin C foods to improve iron absorption\",\"Avoid tea/coffee with meals \\u2014 reduces iron absorption\",\"Include folate: green vegetables, eggs, dairy\"],\"exercise_recommendations\":[\"Light walking only \\u2014 avoid strenuous exercise until values improve\",\"Rest adequately \\u2014 fatigue is common\",\"Gentle Pranayama (breathing exercises)\",\"Avoid high-intensity workouts\"]},{\"test_name\":\"Iron\",\"value\":\"31.00\",\"unit\":\"\\u00B5g/dL\",\"reference_range\":\"65.00 - 175.00\",\"status\":\"Below Average\",\"severity_score\":4,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Low iron levels may indicate iron deficiency.\",\"recommended_actions\":[\"Increase dietary iron intake through foods like red meat, beans, and spinach.\",\"Consider iron supplements after consulting a healthcare provider.\",\"Monitor for symptoms of anemia.\"],\"diet_recommendations\":[\"Include iron-rich foods in your diet.\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Transferrin Saturation\",\"value\":\"9.14\",\"unit\":\"%\",\"reference_range\":\"20.00 - 50.00\",\"status\":\"Below Average\",\"severity_score\":4,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Low transferrin saturation may indicate iron deficiency.\",\"recommended_actions\":[\"Increase dietary iron intake through foods like red meat, beans, and spinach.\",\"Consider iron supplements after consulting a healthcare provider.\",\"Monitor for symptoms of anemia.\"],\"diet_recommendations\":[\"Include iron-rich foods in your diet.\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Total Iron Binding Capacity (TIBC)\",\"value\":\"339.17\",\"unit\":\"\\u00B5g/dL\",\"reference_range\":\"250 - 425\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal TIBC levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Hemoglobin\",\"value\":\"13.10\",\"unit\":\"g/dL\",\"reference_range\":\"13.00 - 17.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal hemoglobin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"RBC Count\",\"value\":\"4.83\",\"unit\":\"mill/mm3\",\"reference_range\":\"4.50 - 5.50\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal red blood cell count.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"MCV\",\"value\":\"83.60\",\"unit\":\"fL\",\"reference_range\":\"83.00 - 101.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal mean corpuscular volume.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"MCH\",\"value\":\"27.10\",\"unit\":\"pg\",\"reference_range\":\"27.00 - 32.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal mean corpuscular hemoglobin.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"MCHC\",\"value\":\"32.50\",\"unit\":\"g/dL\",\"reference_range\":\"31.50 - 34.50\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal mean corpuscular hemoglobin concentration.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Total Leukocyte Count (TLC)\",\"value\":\"8.40\",\"unit\":\"thou/mm3\",\"reference_range\":\"4.00 - 10.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal white blood cell count.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Segmented Neutrophils\",\"value\":\"86.40\",\"unit\":\"%\",\"reference_range\":\"40.00 - 80.00\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"High neutrophil percentage may indicate infection or inflammation.\",\"recommended_actions\":[\"Monitor for signs of infection.\",\"Consult a healthcare provider for further evaluation.\",\"Consider additional tests to identify the cause.\"],\"diet_recommendations\":[\"Eat immunity-boosting foods: citrus fruits, garlic, ginger\",\"Include zinc-rich foods: nuts, seeds, legumes\",\"Stay well hydrated\",\"Avoid processed and junk food\"],\"exercise_recommendations\":[\"Light exercise only \\u2014 avoid overexertion\",\"Walking 20-30 min daily is sufficient\",\"Avoid crowded places if immunity is low\",\"Rest and sleep 7-8 hours\"]},{\"test_name\":\"Lymphocytes\",\"value\":\"6.40\",\"unit\":\"%\",\"reference_range\":\"20.00 - 40.00\",\"status\":\"Below Average\",\"severity_score\":4,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Low lymphocyte percentage may indicate immune suppression.\",\"recommended_actions\":[\"Consult a healthcare provider for further evaluation.\",\"Monitor for signs of infection.\",\"Consider additional tests to identify the cause.\"],\"diet_recommendations\":[\"Eat immunity-boosting foods: citrus fruits, garlic, ginger\",\"Include zinc-rich foods: nuts, seeds, legumes\",\"Stay well hydrated\",\"Avoid processed and junk food\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Monocytes\",\"value\":\"6.60\",\"unit\":\"%\",\"reference_range\":\"2.00 - 10.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal monocyte percentage.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Eosinophils\",\"value\":\"0.30\",\"unit\":\"%\",\"reference_range\":\"1.00 - 6.00\",\"status\":\"Below Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Low eosinophil percentage may indicate immune suppression.\",\"recommended_actions\":[\"Consult a healthcare provider for further evaluation.\",\"Monitor for signs of infection.\",\"Consider additional tests to identify the cause.\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Neutrophils\",\"value\":\"7.26\",\"unit\":\"thou/mm3\",\"reference_range\":\"2.00 - 7.00\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"High neutrophil count may indicate infection or inflammation.\",\"recommended_actions\":[\"Monitor for signs of infection.\",\"Consult a healthcare provider for further evaluation.\",\"Consider additional tests to identify the cause.\"],\"diet_recommendations\":[\"Eat immunity-boosting foods: citrus fruits, garlic, ginger\",\"Include zinc-rich foods: nuts, seeds, legumes\",\"Stay well hydrated\",\"Avoid processed and junk food\"],\"exercise_recommendations\":[\"Light exercise only \\u2014 avoid overexertion\",\"Walking 20-30 min daily is sufficient\",\"Avoid crowded places if immunity is low\",\"Rest and sleep 7-8 hours\"]},{\"test_name\":\"Platelet Count\",\"value\":\"197\",\"unit\":\"thou/mm3\",\"reference_range\":\"150.00 - 410.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal platelet count.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Mean Platelet Volume\",\"value\":\"12.4\",\"unit\":\"fL\",\"reference_range\":\"6.5 - 12.0\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Elevated mean platelet volume may indicate platelet activation.\",\"recommended_actions\":[\"Monitor for signs of clotting disorders.\",\"Consult a healthcare provider for further evaluation.\",\"Consider additional tests to identify the cause.\"],\"diet_recommendations\":[\"Include pomegranate, beetroot, spinach in diet\",\"Papaya and papaya leaf known to support platelets\",\"Avoid alcohol completely\",\"Stay hydrated\"],\"exercise_recommendations\":[\"Avoid contact sports or activities with injury risk\",\"Light walking is fine\",\"No heavy lifting or strenuous activity\"]},{\"test_name\":\"E.S.R.\",\"value\":\"11\",\"unit\":\"mm/hr\",\"reference_range\":\"0 - 15\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal erythrocyte sedimentation rate.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"PSA, TOTAL\",\"value\":\"0.200\",\"unit\":\"ng/mL\",\"reference_range\":\"\\u003C4.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal prostate-specific antigen levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]}],\"top_concerns\":[{\"rank\":1,\"parameter\":\"Alkaline Phosphatase (ALP)\",\"message\":\"Elevated levels may indicate liver or bone issues.\",\"hex_code\":\"#F97316\"},{\"rank\":2,\"parameter\":\"HbA1c\",\"message\":\"Borderline high HbA1c suggests risk for diabetes.\",\"hex_code\":\"#F97316\"},{\"rank\":3,\"parameter\":\"Amylase\",\"message\":\"Elevated amylase may indicate pancreatitis.\",\"hex_code\":\"#F97316\"},{\"rank\":4,\"parameter\":\"Iron\",\"message\":\"Low iron levels may indicate iron deficiency.\",\"hex_code\":\"#EF4444\"},{\"rank\":5,\"parameter\":\"Transferrin Saturation\",\"message\":\"Low transferrin saturation may indicate iron deficiency.\",\"hex_code\":\"#EF4444\"}],\"overall_diet_plan\":[\"Include iron-rich foods in your diet.\"],\"overall_exercise_plan\":[],\"ai_disclaimer\":\"This is AI-generated wellness guidance only. It is not a medical diagnosis. Always consult a qualified doctor before making health decisions.\"}"
;


// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class ReportParameter {
  final String testName;
  final String value;
  final String unit;
  final String referenceRange;
  final String status;
  final int severityScore;
  final String hexCode;
  final String clinicalMeaning;
  final List<String> possibleCauses;
  final List<String> recommendedActions;
  final List<String> dietRecommendations;
  final List<String> exerciseRecommendations;

  ReportParameter.fromJson(Map<String, dynamic> j)
      : testName = j['test_name'] ?? '',
        value = j['value'] ?? '',
        unit = j['unit'] ?? '',
        referenceRange = j['reference_range'] ?? '',
        status = j['status'] ?? '',
        severityScore = j['severity_score'] ?? 0,
        hexCode = j['hex_code'] ?? '#22C55E',
        clinicalMeaning = j['clinical_meaning'] ?? '',
        possibleCauses = List<String>.from(j['possible_causes'] ?? []),
        recommendedActions = List<String>.from(j['recommended_actions'] ?? []),
        dietRecommendations =
            List<String>.from(j['diet_recommendations'] ?? []),
        exerciseRecommendations =
            List<String>.from(j['exercise_recommendations'] ?? []);

  Color get statusColor {
    try {
      final hex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class HealthReport {
  final int overallHealthScore;
  final String overallStatus;
  final bool doctorConsultationRecommended;
  final bool emergencyAttentionNeeded;
  final List<String> keyFindings;
  final List<ReportParameter> parameters;

  HealthReport.fromJson(Map<String, dynamic> j)
      : overallHealthScore = j['overall_health_score'] ?? 0,
        overallStatus = j['overall_status'] ?? '',
        doctorConsultationRecommended =
            j['doctor_consultation_recommended'] ?? false,
        emergencyAttentionNeeded = j['emergency_attention_needed'] ?? false,
        keyFindings = List<String>.from(j['key_findings'] ?? []),
        parameters = (j['parameters'] as List? ?? [])
            .map((e) => ReportParameter.fromJson(e))
            .toList();
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// Two modes:
//   1. Fresh scan  → pass file + fileName + mimeType (historyContent = null)
//   2. History view → pass historyContent JSON string only (file params ignored)
// ─────────────────────────────────────────────
class ReportDetailsScreen extends StatefulWidget {
  final File? file;
  final String? fileName;
  final String? mimeType;
  final String? historyContent;
  final String? historyTitle;

  const ReportDetailsScreen({
    super.key,
    this.file,
    this.fileName,
    this.mimeType,
    this.historyContent,
    this.historyTitle,
  }) : assert(
          historyContent != null ||
              (file != null && fileName != null && mimeType != null),
          'Provide either historyContent (history mode) or file+fileName+mimeType (scan mode)',
        );

  const ReportDetailsScreen.fromHistory({
    super.key,
    required String content,
    required String title,
  })  : historyContent = content,
        historyTitle = title,
        file = null,
        fileName = null,
        mimeType = null;

  bool get isHistoryMode => historyContent != null;

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final ScanReportController _controller = Get.find<ScanReportController>();
  bool _isUploading = false;
  String? _errorMessage;
  HealthReport? _report;

  bool get _isPdf => widget.mimeType == 'application/pdf';

  @override
  void initState() {
    super.initState();
    if (widget.isHistoryMode) {
      _parseContent(widget.historyContent!);
    }
  }

  void _parseContent(String contentJson) {
    try {
      final decoded = jsonDecode(contentJson);
      setState(() => _report = HealthReport.fromJson(decoded));
    } catch (e) {
      setState(() => _errorMessage = 'Failed to parse report: $e');
    }
  }

  Future<void> _uploadFile() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _report = null;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));
      final contentJson = jsonDecode(_dummyApiContent);
      final report = HealthReport.fromJson(contentJson);

      await _controller.addToHistory(
        title: widget.fileName!,
        content: _dummyApiContent,
      );

      setState(() => _report = report);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? scaffoldColorDark : scaffoldColorLight;
    final Color titleColor = isDark ? Colors.white : Colors.black87;
    final String appBarTitle = widget.isHistoryMode
        ? (widget.historyTitle ?? 'Report Details')
        : 'Report Details';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          appBarTitle,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: widget.isHistoryMode
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.secondaryColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    'History',
                    style: TextStyle(
                      color: AppColors.secondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _errorMessage != null && _report == null
          ? _ErrorView(message: _errorMessage!)
          : _report != null
              ? _ReportResultView(
                  report: _report!, isHistoryMode: widget.isHistoryMode)
              : widget.isHistoryMode
                  ? const Center(child: CircularProgressIndicator())
                  : _FilePreviewView(
                      file: widget.file!,
                      fileName: widget.fileName!,
                      mimeType: widget.mimeType!,
                      isPdf: _isPdf,
                      isUploading: _isUploading,
                      errorMessage: _errorMessage,
                      onRetake: () => Navigator.pop(context),
                      onAnalyze: _uploadFile,
                    ),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR VIEW
// ─────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              child: Text(
                'Go Back',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FILE PREVIEW (before upload)
// ─────────────────────────────────────────────
class _FilePreviewView extends StatelessWidget {
  final File file;
  final String fileName;
  final String mimeType;
  final bool isPdf;
  final bool isUploading;
  final String? errorMessage;
  final VoidCallback onRetake;
  final VoidCallback onAnalyze;

  const _FilePreviewView({
    required this.file,
    required this.fileName,
    required this.mimeType,
    required this.isPdf,
    required this.isUploading,
    required this.errorMessage,
    required this.onRetake,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.grey[100]!;
    final Color labelColor = isDark ? Colors.grey : Colors.grey[600]!;
    final Color valueColor = isDark ? Colors.white : Colors.black87;
    final Color borderColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        Expanded(
          child: isPdf
              ? _PdfPreview(fileName: fileName)
              : Image.file(file, fit: BoxFit.contain),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: Icons.insert_drive_file_outlined,
                label: 'File Name',
                value: fileName,
                labelColor: labelColor,
                valueColor: valueColor,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.category_outlined,
                label: 'Type',
                value: mimeType,
                labelColor: labelColor,
                valueColor: valueColor,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.storage_outlined,
                label: 'Size',
                value: '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                labelColor: labelColor,
                valueColor: valueColor,
              ),
            ],
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isUploading ? null : onRetake,
                  child: Text(
                    'Retake',
                    style: TextStyle(color: valueColor),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isUploading ? null : onAnalyze,
                    child: isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Analyze Report',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// REPORT RESULT VIEW (after upload / from history)
// ─────────────────────────────────────────────
class _ReportResultView extends StatelessWidget {
  final HealthReport report;
  final bool isHistoryMode;

  const _ReportResultView({
    required this.report,
    this.isHistoryMode = false,
  });

  Color get _scoreColor {
    final s = report.overallHealthScore;
    if (s >= 80) return const Color(0xFF22C55E);
    if (s >= 50) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScoreCard(report: report, scoreColor: _scoreColor),
          const SizedBox(height: 16),

          if (report.emergencyAttentionNeeded)
            _AlertBanner(
              icon: Icons.emergency,
              color: const Color(0xFFEF4444),
              text: 'Emergency attention needed — visit a doctor immediately.',
            ),
          if (report.doctorConsultationRecommended)
            _AlertBanner(
              icon: Icons.medical_services_outlined,
              color: const Color(0xFFF97316),
              text: 'Doctor consultation recommended based on your results.',
            ),
          if (report.doctorConsultationRecommended ||
              report.emergencyAttentionNeeded)
            const SizedBox(height: 16),

          if (report.keyFindings.isNotEmpty) ...[
            const _SectionTitle(
                title: 'Key Findings', icon: Icons.flag_outlined),
            const SizedBox(height: 8),
            ...report.keyFindings.map((f) => _FindingChip(text: f)),
            const SizedBox(height: 20),
          ],

          const _SectionTitle(
              title: 'Test Parameters', icon: Icons.biotech_outlined),
          const SizedBox(height: 8),
          ...report.parameters.map((p) => _ParameterCard(param: p)),
          const SizedBox(height: 24),

          // Done / Back button — gradient matches rest of app
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => isHistoryMode
                  ? Navigator.pop(context)
                  : Navigator.popUntil(context, (route) => route.isFirst),
              child: Text(
                isHistoryMode ? 'Back' : 'Done',
                style:
                    const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SCORE CARD
// ─────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final HealthReport report;
  final Color scoreColor;

  const _ScoreCard({required this.report, required this.scoreColor});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final Color progressBg = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Overall Health Score',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: report.overallHealthScore / 100,
                  strokeWidth: 9,
                  backgroundColor: progressBg,
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${report.overallHealthScore}',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scoreColor.withOpacity(0.4)),
            ),
            child: Text(
              report.overallStatus,
              style: TextStyle(
                color: scoreColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ALERT BANNER
// ─────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _AlertBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION TITLE
// ─────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: AppColors.secondaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FINDING CHIP
// ─────────────────────────────────────────────
class _FindingChip extends StatelessWidget {
  final String text;

  const _FindingChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFFF97316), size: 7),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PARAMETER CARD (expandable)
// ─────────────────────────────────────────────
class _ParameterCard extends StatefulWidget {
  final ReportParameter param;

  const _ParameterCard({required this.param});

  @override
  State<_ParameterCard> createState() => _ParameterCardState();
}

class _ParameterCardState extends State<_ParameterCard> {
  bool _expanded = false;

  bool get _hasDetails =>
      widget.param.possibleCauses.isNotEmpty ||
      widget.param.recommendedActions.isNotEmpty ||
      widget.param.dietRecommendations.isNotEmpty ||
      widget.param.exerciseRecommendations.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final Color titleColor = isDark ? Colors.white : Colors.black87;
    final Color dividerColor = isDark ? Colors.white12 : Colors.black12;
    final p = widget.param;
    final color = p.statusColor;

    return GestureDetector(
      onTap: _hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.testName,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.value} ${p.unit}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Ref: ${p.referenceRange}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.status,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_hasDetails) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),

            if (p.clinicalMeaning.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(34, 0, 14, 12),
                child: Text(
                  p.clinicalMeaning,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),

            if (_expanded && _hasDetails)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: dividerColor, height: 16),
                    if (p.possibleCauses.isNotEmpty)
                      _DetailSection(
                        icon: Icons.help_outline,
                        title: 'Possible Causes',
                        items: p.possibleCauses,
                        color: const Color(0xFFF97316),
                      ),
                    if (p.recommendedActions.isNotEmpty)
                      _DetailSection(
                        icon: Icons.check_circle_outline,
                        title: 'Recommended Actions',
                        items: p.recommendedActions,
                        color: const Color(0xFF22C55E),
                      ),
                    if (p.dietRecommendations.isNotEmpty)
                      _DetailSection(
                        icon: Icons.restaurant_outlined,
                        title: 'Diet',
                        items: p.dietRecommendations,
                        color: const Color(0xFF3B82F6),
                      ),
                    if (p.exerciseRecommendations.isNotEmpty)
                      _DetailSection(
                        icon: Icons.fitness_center_outlined,
                        title: 'Exercise',
                        items: p.exerciseRecommendations,
                        color: const Color(0xFFA855F7),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DETAIL SECTION
// ─────────────────────────────────────────────
class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color itemColor = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontSize: 12)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: itemColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: labelColor, size: 18),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(color: labelColor, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PdfPreview extends StatelessWidget {
  final String fileName;

  const _PdfPreview({required this.fileName});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 100, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            fileName,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'PDF ready to analyze',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}