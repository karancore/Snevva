import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snevva/views/scan_report/scan_report_landing_screen.dart';

import '../../Controllers/ReportScan/scan_report_controller.dart';
import '../../Controllers/local_storage_manager.dart';
import '../../consts/colors.dart';
import '../../models/health_report.dart';
import '../../services/report_pdf_generator.dart';

// ─────────────────────────────────────────────
// DUMMY DATA — replace with real API call later
// ─────────────────────────────────────────────

const String _dummy =
    "{\"overall_health_score\":84,\"overall_status\":\"Good\",\"doctor_consultation_recommended\":true,\"urgent_medical_review_needed\":false,\"key_findings\":[\"Your Iron is lower than normal (31.00 \\u00B5g/dL). Low iron levels may indicate iron deficiency.\",\"Your Transferrin Saturation is lower than normal (9.14 %). Low transferrin saturation may indicate iron deficiency.\",\"Your RDW is higher than normal (15.30 %). Elevated RDW may indicate variability in red blood cell size.\",\"Your Lymphocytes is lower than normal (6.40 %). Low lymphocyte count may indicate immune issues.\",\"Your Alkaline Phosphatase is higher than normal (129.00 U/L). Slightly elevated alkaline phosphatase may indicate liver or bone issues.\",\"Your Bilirubin Direct is higher than normal (0.33 mg/dL). Slightly elevated direct bilirubin may indicate liver issues.\"],\"parameters\":[{\"test_name\":\"Creatinine\",\"value\":\"1.10\",\"unit\":\"mg/dL\",\"reference_range\":\"0.70 - 1.30\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal kidney function.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"GFR Estimated\",\"value\":\"86\",\"unit\":\"mL/min/1.73m2\",\"reference_range\":\"\\u003E59\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal kidney filtration rate.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Urea\",\"value\":\"29.00\",\"unit\":\"mg/dL\",\"reference_range\":\"13.00 - 43.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal urea levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Uric Acid\",\"value\":\"6.20\",\"unit\":\"mg/dL\",\"reference_range\":\"3.50 - 7.20\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal uric acid levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"AST (SGOT)\",\"value\":\"22.0\",\"unit\":\"U/L\",\"reference_range\":\"15.00 - 40.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal liver enzyme levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"ALT (SGPT)\",\"value\":\"25.0\",\"unit\":\"U/L\",\"reference_range\":\"10.00 - 49.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal liver enzyme levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"AST:ALT Ratio\",\"value\":\"0.88\",\"unit\":\"\",\"reference_range\":\"\\u003C1.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal liver function.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"GGTP\",\"value\":\"24.0\",\"unit\":\"U/L\",\"reference_range\":\"0 - 73\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal liver function.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Alkaline Phosphatase\",\"value\":\"129.00\",\"unit\":\"U/L\",\"reference_range\":\"30.00 - 120.00\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Slightly elevated alkaline phosphatase may indicate liver or bone issues.\",\"recommended_actions\":[\"Consider further evaluation of liver function.\",\"Monitor for symptoms of liver disease.\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Bilirubin Total\",\"value\":\"0.99\",\"unit\":\"mg/dL\",\"reference_range\":\"0.30 - 1.20\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal bilirubin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Bilirubin Direct\",\"value\":\"0.33\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C0.3\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Slightly elevated direct bilirubin may indicate liver issues.\",\"recommended_actions\":[\"Consider further evaluation of liver function.\",\"Monitor for symptoms of liver disease.\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Bilirubin Indirect\",\"value\":\"0.66\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C1.10\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal indirect bilirubin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Total Protein\",\"value\":\"7.00\",\"unit\":\"g/dL\",\"reference_range\":\"5.70 - 8.20\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal protein levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Albumin\",\"value\":\"4.57\",\"unit\":\"g/dL\",\"reference_range\":\"3.20 - 4.80\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal albumin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Globulin\",\"value\":\"2.43\",\"unit\":\"g/dL\",\"reference_range\":\"2.0 - 3.5\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal globulin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Calcium, Total\",\"value\":\"9.30\",\"unit\":\"mg/dL\",\"reference_range\":\"8.70 - 10.40\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal calcium levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Phosphorus\",\"value\":\"2.80\",\"unit\":\"mg/dL\",\"reference_range\":\"2.40 - 5.10\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal phosphorus levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Sodium\",\"value\":\"140.00\",\"unit\":\"mEq/L\",\"reference_range\":\"136.00 - 145.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal sodium levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Potassium\",\"value\":\"4.53\",\"unit\":\"mEq/L\",\"reference_range\":\"3.50 - 5.10\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal potassium levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Chloride\",\"value\":\"104.00\",\"unit\":\"mEq/L\",\"reference_range\":\"98.00 - 107.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal chloride levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Cholesterol, Total\",\"value\":\"158.00\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C200.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal total cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Triglycerides\",\"value\":\"102.00\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C150.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal triglyceride levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"HDL Cholesterol\",\"value\":\"45.30\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003E40.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal HDL cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"LDL Cholesterol, Calculated\",\"value\":\"92.30\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C100.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal LDL cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"VLDL Cholesterol,Calculated\",\"value\":\"20.40\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C30.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal VLDL cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Non-HDL Cholesterol\",\"value\":\"113\",\"unit\":\"mg/dL\",\"reference_range\":\"\\u003C130\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal non-HDL cholesterol levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"TSH\",\"value\":\"0.87\",\"unit\":\"\\u00B5IU/mL\",\"reference_range\":\"0.550 - 4.780\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal thyroid function.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"T3, Total\",\"value\":\"1.56\",\"unit\":\"ng/mL\",\"reference_range\":\"0.60 - 1.81\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal T3 levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"T4, Total\",\"value\":\"8.30\",\"unit\":\"\\u00B5g/dL\",\"reference_range\":\"4.50 - 11.60\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal T4 levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Amylase\",\"value\":\"125.00\",\"unit\":\"U/L\",\"reference_range\":\"30.00 - 118.00\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Elevated amylase may indicate pancreatic issues.\",\"recommended_actions\":[\"Consider further evaluation of pancreatic function.\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Iron\",\"value\":\"31.00\",\"unit\":\"\\u00B5g/dL\",\"reference_range\":\"65.00 - 175.00\",\"status\":\"Below Average\",\"severity_score\":4,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Low iron levels may indicate iron deficiency.\",\"recommended_actions\":[\"Consider iron supplementation.\",\"Evaluate dietary intake of iron-rich foods.\"],\"diet_recommendations\":[\"Include more red meat, beans, and leafy greens.\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Total Iron Binding Capacity (TIBC)\",\"value\":\"339.17\",\"unit\":\"\\u00B5g/dL\",\"reference_range\":\"250 - 425\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal iron binding capacity.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Transferrin Saturation\",\"value\":\"9.14\",\"unit\":\"%\",\"reference_range\":\"20.00 - 50.00\",\"status\":\"Below Average\",\"severity_score\":4,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Low transferrin saturation may indicate iron deficiency.\",\"recommended_actions\":[\"Consider iron supplementation.\",\"Evaluate dietary intake of iron-rich foods.\"],\"diet_recommendations\":[\"Include more red meat, beans, and leafy greens.\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Hemoglobin\",\"value\":\"13.10\",\"unit\":\"g/dL\",\"reference_range\":\"13.00 - 17.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal hemoglobin levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Hematocrit\",\"value\":\"40.30\",\"unit\":\"%\",\"reference_range\":\"40.00 - 50.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal hematocrit levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"RBC Count\",\"value\":\"4.83\",\"unit\":\"mill/mm3\",\"reference_range\":\"4.50 - 5.50\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal red blood cell count.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"MCV\",\"value\":\"83.60\",\"unit\":\"fL\",\"reference_range\":\"83.00 - 101.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal mean corpuscular volume.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"MCH\",\"value\":\"27.10\",\"unit\":\"pg\",\"reference_range\":\"27.00 - 32.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal mean corpuscular hemoglobin.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"MCHC\",\"value\":\"32.50\",\"unit\":\"g/dL\",\"reference_range\":\"31.50 - 34.50\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal mean corpuscular hemoglobin concentration.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"RDW\",\"value\":\"15.30\",\"unit\":\"%\",\"reference_range\":\"11.60 - 14.00\",\"status\":\"Above Average\",\"severity_score\":4,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Elevated RDW may indicate variability in red blood cell size.\",\"recommended_actions\":[\"Consider further evaluation for anemia.\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Total Leukocyte Count\",\"value\":\"8.40\",\"unit\":\"thou/mm3\",\"reference_range\":\"4.00 - 10.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal white blood cell count.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Segmented Neutrophils\",\"value\":\"86.40\",\"unit\":\"%\",\"reference_range\":\"40.00 - 80.00\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Elevated neutrophils may indicate infection or inflammation.\",\"recommended_actions\":[\"Consider further evaluation for infection.\"],\"diet_recommendations\":[\"Eat immunity-boosting foods: citrus fruits, garlic, ginger\",\"Include zinc-rich foods: nuts, seeds, legumes\",\"Stay well hydrated\",\"Avoid processed and junk food\"],\"exercise_recommendations\":[\"Light exercise only \\u2014 avoid overexertion\",\"Walking 20-30 min daily is sufficient\",\"Avoid crowded places if immunity is low\",\"Rest and sleep 7-8 hours\"]},{\"test_name\":\"Lymphocytes\",\"value\":\"6.40\",\"unit\":\"%\",\"reference_range\":\"20.00 - 40.00\",\"status\":\"Below Average\",\"severity_score\":4,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Low lymphocyte count may indicate immune issues.\",\"recommended_actions\":[\"Consider further evaluation of immune function.\"],\"diet_recommendations\":[\"Eat immunity-boosting foods: citrus fruits, garlic, ginger\",\"Include zinc-rich foods: nuts, seeds, legumes\",\"Stay well hydrated\",\"Avoid processed and junk food\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Monocytes\",\"value\":\"6.60\",\"unit\":\"%\",\"reference_range\":\"2.00 - 10.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal monocyte count.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Eosinophils\",\"value\":\"0.30\",\"unit\":\"%\",\"reference_range\":\"1.00 - 6.00\",\"status\":\"Below Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Eosinophils is lower than the normal range and may need medical attention.\",\"recommended_actions\":[\"Consult your doctor about this result\",\"Recheck Eosinophils in 4-6 weeks\",\"Follow doctor\\u0027s prescribed treatment\"],\"diet_recommendations\":[\"Eat balanced meals with adequate protein and vegetables\",\"Avoid processed foods and excess salt/sugar\",\"Stay hydrated \\u2014 8-10 glasses water daily\",\"Consult doctor for specific dietary guidance\"],\"exercise_recommendations\":[\"30 minutes moderate exercise daily\",\"Walking, yoga, or light stretching recommended\",\"Consult doctor before starting intense exercise\"]},{\"test_name\":\"Platelet Count\",\"value\":\"197\",\"unit\":\"thou/mm3\",\"reference_range\":\"150.00 - 410.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal platelet count.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Mean Platelet Volume\",\"value\":\"12.4\",\"unit\":\"fL\",\"reference_range\":\"6.5 - 12.0\",\"status\":\"Above Average\",\"severity_score\":2,\"status_color\":\"orange\",\"hex_code\":\"#F97316\",\"clinical_meaning\":\"Slightly elevated mean platelet volume may indicate platelet activation.\",\"recommended_actions\":[\"Consider further evaluation of platelet function.\"],\"diet_recommendations\":[\"Include pomegranate, beetroot, spinach in diet\",\"Papaya and papaya leaf known to support platelets\",\"Avoid alcohol completely\",\"Stay hydrated\"],\"exercise_recommendations\":[\"Avoid contact sports or activities with injury risk\",\"Light walking is fine\",\"No heavy lifting or strenuous activity\"]},{\"test_name\":\"E.S.R.\",\"value\":\"11\",\"unit\":\"mm/hr\",\"reference_range\":\"0 - 15\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal erythrocyte sedimentation rate.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"PSA, TOTAL\",\"value\":\"0.200\",\"unit\":\"ng/mL\",\"reference_range\":\"\\u003C4.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal prostate-specific antigen levels.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"A : G Ratio\",\"value\":\"1.88\",\"unit\":\"Ratio\",\"reference_range\":\"0.90 - 2.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Normal A/G ratio indicates balanced protein levels\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]},{\"test_name\":\"Vitamin-D 25 Hydroxy\",\"value\":\"94.88\",\"unit\":\"nmol/L\",\"reference_range\":\"75.00 - 250.00\",\"status\":\"Good\",\"severity_score\":1,\"status_color\":\"green\",\"hex_code\":\"#22C55E\",\"clinical_meaning\":\"Vitamin D is essential for bone health.\",\"recommended_actions\":[],\"diet_recommendations\":[],\"exercise_recommendations\":[]}],\"top_concerns\":[{\"rank\":1,\"parameter\":\"HbA1c\",\"message\":\"At risk for Diabetes (Prediabetes)\",\"hex_code\":\"#EF4444\"},{\"rank\":2,\"parameter\":\"C-REACTIVE PROTEIN HIGH SENSITIVITY\",\"message\":\"Persistent elevation may indicate inflammation\",\"hex_code\":\"#EF4444\"},{\"rank\":3,\"parameter\":\"Iron\",\"message\":\"Low iron levels may indicate deficiency\",\"hex_code\":\"#EF4444\"},{\"rank\":4,\"parameter\":\"Transferrin Saturation\",\"message\":\"Low transferrin saturation may indicate deficiency\",\"hex_code\":\"#EF4444\"},{\"rank\":5,\"parameter\":\"Segmented Neutrophils\",\"message\":\"Elevated neutrophils may indicate infection\",\"hex_code\":\"#EF4444\"},{\"rank\":6,\"parameter\":\"Mean Platelet Volume\",\"message\":\"Slightly elevated may indicate activation\",\"hex_code\":\"#EF4444\"}],\"overall_diet_plan\":[\"Include more iron-rich foods such as red meat, beans, and leafy greens.\"],\"overall_exercise_plan\":[\"Engage in regular physical activity to maintain healthy blood sugar levels.\"],\"recommendations\":[],\"patient_summary\":\"The patient has normal kidney and liver function tests, but shows elevated HbA1c indicating prediabetes and high sensitivity CRP suggesting inflammation.\",\"ai_disclaimer\":\"This is AI-generated wellness guidance only. It is not a medical diagnosis. Always consult a qualified doctor before making health decisions.\",\"merge_meta\":{\"source\":\"KB\\u002BAI\",\"total_params\":55,\"ai_params\":50,\"kb_params\":5,\"merged_at\":\"2026-06-16T06:37:37.1367360Z\"}}";

// ─────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────
class ReportDetailsScreen extends StatefulWidget {
  final File? file;
  final String? fileName;
  final String? mimeType;
  final String? historyContent;
  final String? historyTitle;
  final bool isOwnPdf;
  final String? enteredName;
  final String? enteredAge;
  final String? enteredGender;

  const ReportDetailsScreen({
    super.key,
    this.file,
    this.fileName,
    this.mimeType,
    this.historyContent,
    this.historyTitle,
    this.isOwnPdf = true,
    this.enteredName,
    this.enteredAge,
    this.enteredGender,
  }) : assert(
  historyContent != null ||
      (file != null && fileName != null && mimeType != null),
  'Provide either historyContent (history mode) or file+fileName+mimeType (scan mode)',
  );

  const ReportDetailsScreen.fromHistory({
    super.key,
    required String content,
    required String title,
  })
      : historyContent = content,
        historyTitle = title,
        file = null,
        fileName = null,
        mimeType = null,
        isOwnPdf = true,
        enteredName = null,
        enteredAge = null,
        enteredGender = null;

  bool get isHistoryMode => historyContent != null;

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final ScanReportController _controller = Get.find<ScanReportController>();
  bool _isUploading = false;
  String? _errorMessage;
  bool _isGeneratingPdf = false;
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
      final contentJson = jsonDecode(_dummy);
      final report = HealthReport.fromJson(contentJson);

      String resolvedName;
      String resolvedGender;
      String resolvedAge;

      if (widget.isOwnPdf) {
        final userInfo = Get
            .find<LocalStorageManager>()
            .userMap;
        resolvedName = userInfo['Name'] ?? '';
        resolvedGender = userInfo['Gender'] ?? '';
        final day = userInfo['DayOfBirth'];
        final month = userInfo['MonthOfBirth'];
        final year = userInfo['YearOfBirth'];
        resolvedAge =
            _controller
                .calculateAge(day: day, month: month, year: year)
                .toString();
      } else {
        resolvedName = widget.enteredName ?? '';
        resolvedGender = widget.enteredGender ?? '';
        resolvedAge = widget.enteredAge ?? '';
      }

      await _controller.addToHistory(
        title: widget.fileName!,
        content: _dummy,
        patientName: resolvedName,
        gender: resolvedGender,
        ageRange: resolvedAge,
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

  Future<Directory> _resolveDownloadsDirectory() async {
    if (Platform.isAndroid) {
      try {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      } catch (e) {
        debugPrint("Error requesting storage permission: $e");
      }

      final Directory dir = Directory('/storage/emulated/0/Download');
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        // Test write access
        final testFile = File('${dir.path}/.test_write');
        await testFile.writeAsString('test');
        await testFile.delete();
        return dir;
      } catch (e) {
        debugPrint("Android Download directory not writable, falling back: $e");
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  String _resolveTitle() {
    if (widget.historyTitle != null && widget.historyTitle!.trim().isNotEmpty) {
      return widget.historyTitle!;
    }

    final patientName = widget.isOwnPdf
        ? (Get
        .find<LocalStorageManager>()
        .userMap['Name'] ?? '')
        : (widget.enteredName ?? '');

    final dateStr = DateFormat('d MMM yyyy').format(DateTime.now());

    if (patientName
        .trim()
        .isNotEmpty) {
      return "$patientName's Health Report - $dateStr";
    }

    return widget.fileName != null
        ? 'Health Report - $dateStr'
        : 'Health Report';
  }

  Future<void> _downloadReportPdf() async {
    if (_report == null || _isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final title = _resolveTitle();
      final downloadDir = await _resolveDownloadsDirectory();

      final file = await ReportPdfGenerator.generate(
        report: _report!,
        title: title,
        customDirectory: downloadDir,
      );

      if (mounted) {
        Get.snackbar(
          'PDF Downloaded!',
          '',
          snackPosition: SnackPosition.BOTTOM,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 3),
        );

        await OpenFile.open(file.path);
      }
    } catch (e, st) {
      debugPrint("Exception of pdf $e");
      debugPrint("Stack trace of pdf $st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? scaffoldColorDark : scaffoldColorLight;
    final Color titleColor = isDark ? Colors.white : Colors.black87;
    final String appBarTitle =
    widget.isHistoryMode
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
        actions: [
          if (_report != null)
            IconButton(
              onPressed: _isGeneratingPdf ? null : _downloadReportPdf,
              icon: _isGeneratingPdf
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: titleColor,
                ),
              )
                  : Icon(Icons.download, color: titleColor),
            )
          else
            if (widget.isHistoryMode)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
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
        ],
      ),
      body:
      _errorMessage != null && _report == null
          ? _ErrorView(message: _errorMessage!)
          : _report != null
          ? _ReportResultView(
        report: _report!,
        isHistoryMode: widget.isHistoryMode,
      )
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
      bottomNavigationBar:
      _report != null
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
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
              onPressed: () => Get.offAll(() => ScanReportLandingScreen()),
              child: Text(
                'Done',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      )
          : null,
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
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              child: Text(
                'Go Back',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
          child:
          isPdf
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
                  child: Text('Retake', style: TextStyle(color: valueColor)),
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
                    child:
                    isUploading
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

  const _ReportResultView({required this.report, this.isHistoryMode = false});

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
          // ── 1. Health Score Card ──────────────────
          _ScoreCard(report: report, scoreColor: _scoreColor),
          const SizedBox(height: 16),

          // ── 2. Alert Banners ─────────────────────
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

          // ── 3. Patient Summary ───────────────────
          // if (report.patientSummary.isNotEmpty) ...[
          //   const _SectionTitle(
          //       title: 'Patient Summary', icon: Icons.person_outline),
          //   const SizedBox(height: 8),
          //   _PatientSummaryCard(summary: report.patientSummary),
          //   const SizedBox(height: 20),
          // ],

          // ── 4. Key Findings ──────────────────────
          if (report.keyFindings.isNotEmpty) ...[
            const _SectionTitle(
              title: 'Key Findings',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 8),
            ...report.keyFindings.map((f) => _FindingChip(text: f)),
            const SizedBox(height: 20),
          ],

          // ── 5. Top Concerns ──────────────────────
          if (report.topConcerns.isNotEmpty) ...[
            const _SectionTitle(
              title: 'Top Concerns',
              icon: Icons.warning_amber_outlined,
            ),
            const SizedBox(height: 8),
            _TopConcernsCard(concerns: report.topConcerns),
            const SizedBox(height: 20),
          ],

          // ── 6. Overall Diet Plan ─────────────────
          if (report.overallDietPlan.isNotEmpty) ...[
            const _SectionTitle(
              title: 'Overall Diet Plan',
              icon: Icons.restaurant_outlined,
            ),
            const SizedBox(height: 8),
            _PlanCard(
              items: report.overallDietPlan,
              accentColor: const Color(0xFF3B82F6),
              bulletIcon: Icons.local_dining_outlined,
            ),
            const SizedBox(height: 20),
          ],

          // ── 7. Overall Exercise Plan ─────────────
          if (report.overallExercisePlan.isNotEmpty) ...[
            const _SectionTitle(
              title: 'Overall Exercise Plan',
              icon: Icons.fitness_center_outlined,
            ),
            const SizedBox(height: 8),
            _PlanCard(
              items: report.overallExercisePlan,
              accentColor: const Color(0xFFA855F7),
              bulletIcon: Icons.directions_run_outlined,
            ),
            const SizedBox(height: 20),
          ],

          // ── 8. Recommendations ───────────────────
          if (report.recommendations.isNotEmpty) ...[
            const _SectionTitle(
              title: 'Recommendations',
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 8),
            _PlanCard(
              items: report.recommendations,
              accentColor: const Color(0xFF22C55E),
              bulletIcon: Icons.tips_and_updates_outlined,
            ),
            const SizedBox(height: 20),
          ],

          // ── 9. Test Parameters ───────────────────
          const _SectionTitle(
            title: 'Test Parameters',
            icon: Icons.biotech_outlined,
          ),
          const SizedBox(height: 8),
          ...report.parameters.map((p) => _ParameterCard(param: p)),
          const SizedBox(height: 20),

          // ── 11. AI Disclaimer ────────────────────
          if (report.aiDisclaimer.isNotEmpty) ...[
            _AiDisclaimerBanner(text: report.aiDisclaimer),
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

  const _AlertBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

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
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PATIENT SUMMARY CARD  ← NEW
// ─────────────────────────────────────────────
class _PatientSummaryCard extends StatelessWidget {
  final String summary;

  const _PatientSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final Color textColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        summary,
        style: TextStyle(color: textColor, fontSize: 13, height: 1.55),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TOP CONCERNS CARD  ← NEW
// ─────────────────────────────────────────────
class _TopConcernsCard extends StatelessWidget {
  final List<TopConcern> concerns;

  const _TopConcernsCard({required this.concerns});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final Color dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children:
        concerns
            .asMap()
            .entries
            .map((entry) {
          final i = entry.key;
          final c = entry.value;
          return Column(
            children: [
              if (i != 0) Divider(height: 1, color: dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.color.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: c.color.withOpacity(0.5)),
                      ),
                      child: Text(
                        '${c.rank}',
                        style: TextStyle(
                          color: c.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.parameter,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.message,
                            style: TextStyle(
                              color:
                              isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Icon(Icons.chevron_right,
                    //     color: c.color.withOpacity(0.7), size: 18),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PLAN CARD (diet / exercise / recommendations) ← NEW
// ─────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final List<String> items;
  final Color accentColor;
  final IconData bulletIcon;

  const _PlanCard({
    required this.items,
    required this.accentColor,
    required this.bulletIcon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final Color textColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children:
        items
            .map(
              (item) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(bulletIcon, color: accentColor, size: 15),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        )
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MERGE META CARD  ← NEW
// ─────────────────────────────────────────────
class _MergeMetaCard extends StatelessWidget {
  final MergeMeta meta;

  const _MergeMetaCard({required this.meta});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final Color labelColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    final Color valueColor = isDark ? Colors.white : Colors.black87;
    final Color dividerColor = isDark ? Colors.white10 : Colors.black12;

    final rows = [
      _MetaRow(label: 'Source', value: meta.source),
      _MetaRow(label: 'Analyzed on', value: meta.formattedDate),
      _MetaRow(label: 'Total parameters', value: '${meta.totalParams}'),
      _MetaRow(label: 'AI analyzed', value: '${meta.aiParams} params'),
      _MetaRow(label: 'KB matched', value: '${meta.kbParams} params'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children:
        rows
            .asMap()
            .entries
            .map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Column(
            children: [
              if (i != 0) Divider(height: 1, color: dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: TextStyle(color: labelColor, fontSize: 12),
                    ),
                    Text(
                      row.value,
                      style: TextStyle(
                            color: valueColor,
                            fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MetaRow {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});
}

// ─────────────────────────────────────────────
// AI DISCLAIMER BANNER  ← NEW
// ─────────────────────────────────────────────
class _AiDisclaimerBanner extends StatelessWidget {
  final String text;

  const _AiDisclaimerBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final Color bg = isDark ? Colors.grey[850]! : Colors.grey[100]!;
    final Color border = isDark ? Colors.white12 : Colors.black12;
    final Color textColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: textColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
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
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
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
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
// DETAIL SECTION (inside expandable param card)
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
                (item) =>
                Padding(
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
        Text('$label: ', style: TextStyle(color: labelColor, fontSize: 13)),
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
