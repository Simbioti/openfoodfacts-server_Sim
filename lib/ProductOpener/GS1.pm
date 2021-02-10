# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This package is used to convert CSV or XML file sent by producers to
# an Open Food Facts CSV file that can be loaded with import_csv_file.pl / Import.pm

=head1 NAME

ProductOpener::GS1 - convert data from GS1 Global Data Synchronization Network (GDSN) to the Open Food Facts format.

=head1 SYNOPSIS

=head1 DESCRIPTION

..

=cut

package ProductOpener::GS1;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);


BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		%gs1_maps

		&init_csv_fields
		&read_gs1_json_file
		&write_off_csv_file
		&print_unknown_entries_in_gs1_maps

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;

use JSON::PP;
use boolean;

# specify language fields here instead of importing Tags.pm to speed up execution

# Fields that can have different values by language
my %language_fields = (
front_image => 1,
ingredients_image => 1,
nutrition_image => 1,
product_name => 1,
generic_name => 1,
ingredients_text => 1,
conservation_conditions => 1,
other_information => 1,
packaging_text => 1,
recycling_instructions_to_recycle => 1,
recycling_instructions_to_discard => 1,
producer => 1,
origin => 1,
preparation => 1,
warning => 1,
recipe_idea => 1,
customer_service => 1,
product_infocard => 1,
ingredients_infocard => 1,
nutrition_infocard => 1,
environment_infocard => 1,
);

=head1 GS1 MAPS

GS1 uses many different codes for allergens, packaging etc.
We need to map the different values to the values we use in the taxonomies.

The GS1 standards are evolving, so new values may be introduced over time.

=head2 %unknown_entries_in_gs1_maps

Used to keep track of values we encounter in GS1 data for which we do not have a mapping.

=head2 %gs1_maps

Maps from GS1 to OFF

=cut


my %unknown_entries_in_gs1_maps = ();

# see https://www.gs1.fr/content/download/2265/17736/version/3/file/FicheProduit3.1.9_PROFIL_ParfumerieSelective_20190523.xlsx

%gs1_maps = (

	# gs1:$gs1_maps
	allergenTypeCode => {

		"AC" => "Crustacés",
		"AE" => "Oeuf",
		"AF" => "Poisson",
		"AM" => "Lait",
		"AN" => "Fruits à coque",
		"AP" => "Cacahuètes",
		"AS" => "Sésame",
		"AU" => "Sulfites",
		"AW" => "Gluten",
		"AY" => "Soja",
		"BC" => "Céleri",
		"BM" => "Moutarde",
		"GB" => "Orge",
		"NL" => "Lupin",
		"SA" => "Amandes",
		"SB" => "Graines",
		"SH" => "Noisette",
		"SW" => "Noix",
		"UM" => "Mollusques",
		"UW" => "Blé",
	},
	
	measurementUnitCode => {
		"GRM" => "g",
		"KGM" => "kg",
		"MGM" => "mg",
		"MC" => "mcg",
		"MLT" => "ml",
		"CLT" => "cl",
		"LTR" => "L",
		"E14" => "kcal",
		"KJO" => "kJ",
		"H87" => "pièces",
	},
	
	# reference: GS1 T4073 Nutrient type code
	# https://gs1.se/en/guides/documentation/test-code-lists/t4073-nutrient-type-code/
	nutrientTypeCode => {
		"BIOT" => "biotin",
		"CA" => "calcium",
		"CHOAVL" => "carbohydrates",
		"CLD" => "chloride",
		"CR" => "chromium",
		"CU" => "copper",
		"ENER-" => "energy",
		"ENERSF" => "calories-from-saturated-fat",
		"FAT" => "fat",
		"FASAT" => "saturated-fat",
		"FAMSCIS" => "monounsaturated-fat",
		"FAPUCIS" => "polyunsaturated-fat",
		"FD" => "fluoride",
		"FE" => "iron",
		"FIBTG" => "fiber",
		"FOL" => "folates",
		"FOLDFE" => "vitamin-b9",
		# G_ entries: cigarettes?
		#"G_CMO" => "carbon-monoxide",
		#"G_HC" => "bicarbonate",
		#"G_NICT" => "nicotine",
		#"G_NMES" => "non-milk-extrinsic-sugars",
		#"G_TAR" => "tar",
		"GINSENG" => "ginseng",
		"HMB" => "beta-hydroxy-beta-methylburate",
		"ID" => "iodine",
		"IODIZED_SALT" => "iodized_salt",
		"K" => "potassium",
		"L_CARNITINE" => "carnitine",
		"MG" => "magnesium",
		"MN" => "manganese",
		"MO" => "molybdenum",
		"NA" => "sodium",
		"NACL" => "nacl",
		"NIA" => "vitamin-pp",
		"NUCLEOTIDE" => "nucleotide",
		"P" => "phosphorus",
		"PANTAC" => "pantothenic-acid",
		"POLYLS" => "polyols",	
		"PRO-" => "proteins",
		"RIBF" => "vitamin-b2",
		"SALTEQ" => "salt",
		"SE" => "selenium",
		"STARCH" => "starch",
		"SUGAR" => "sugars",
		"SUGAR-" => "sugars",
		"THIA-" => "vitamin-b1",
		"VITA-" => "vitamin-a",
		"VITB12" => "vitamin-b12",
		"VITB6-" => "vitamin-b6",
		"VITC-" => "vitamin-c",
		"VITD-" => "vitamin-d",
		"VITE-" => "vitamin-e",
		"VITK-" => "vitamin-k",
		"VITK" => "vitamin-k",
		# skipped X_ entries such as X_ACAI_BERRY_EXTRACT
		"ZN" => "zinc",
	},
	
	packagingTypeCode => {
		"AE" => "Aérosol",
		"BG" => "Sac",
		"BK" => "Barquette",
		"BO" => "Bouteille",
		"BPG" => "Blister",
		"BRI" => "Brique",
		"BX" => "Boite",
		"CNG" => "Canette",
		"CR" => "Caisse",
		"CU" => "Pot",
		"EN" => "Enveloppe",
		"JR" => "Bocal",
		"PO" => "Poche",
		"TU" => "Tube",
		"WRP" => "Film",
	},		
	
	packagingTypeCode_unused_not_taxonomized_yet => {
		"AE" => "en:aerosol",
		"BG" => "en:bag",
		"BK" => "en:tray",
		"BO" => "en:bottle",
		"BPG" => "en:film",
		"BRI" => "en:brick",
		"BX" => "en:box",
		"CNG" => "en:can",
		"CR" => "en:crate",
		"EN" => "en:envelope",
		"JR" => "en:jar",
		"PO" => "en:bag",
		"TU" => "en:tube",
		"WRP" => "en:film",
	},	
	
	packagingMarkedLabelAccreditationCode => {
		"AGRICULTURE_BIOLOGIQUE" => "en:organic",
		# mispelling present in many files
		"AGRICULTURE_BIOLIGIQUE" => "en:organic",
		"DEMETER" => "en:demeter",
		"EU_ORGANIC_FARMING" => "en:eu-organic",
		"FAIR_TRADE_MARK" => "en:fairtrade-international",
		"GREEN_DOT" => "en:green-dot",
		"MAX_HAVELAAR" => "en:max-havelaar",
		"RAINFOREST_ALLIANCE" => "en:rainforest-alliance",
		"TRIMAN" => "en:triman",
		"UTZ_CERTIFIED" => "en:utz-certified",
	},
	
	targetMarketCountryCode => {
		"250" => "en:france",
	},
	
	timeMeasurementUnitCode => {
		"MON" => "month",
		"DAY" => "day",
	},	
);


=head2 %gs1_to_off

Defines the structure of the GS1 data and how it maps to the OFF data.

=cut

my %gs1_to_off = (

	match => [
		["isTradeItemAConsumerUnit", "true"],
	],

	fields => [
	
		# source_field => target_field : assign the value of the source field to the target field
		["gtin", "code"],

		# source_field => source_hash : go down one level
		["brandOwner", {
				fields => [
					["gln", "sources_fields:org-gs1:gln"],
					# source_field => target_field1,target_field2 : assign value of the source field to multiple target fields
					["partyName", "sources_fields:org-gs1:partyName, org_name"],
				],
			},
		],
		
		["gdsnTradeItemClassification", {
				fields => [
					["gpcCategoryCode", "sources_fields:org-gs1:gpcCategoryCode"],
					# not always present and could be in different languages
					["gpcCategoryName", "sources_fields:org-gs1:gpcCategoryName, +categories_if_match_in_taxonomy"],
				],
			},
		],		
			
		["informationProviderOfTradeItem", {
				fields => [
					["gln", "sources_fields:org-gs1:gln"],
					# source_field => target_field1,target_field2 : assign value of the source field to multiple target fields
					["partyName", "sources_fields:org-gs1:partyName, org_name"],
				],
			},
		],
		
		["targetMarket", {
				fields => [
					["targetMarketCountryCode", "countries%targetMarketCountryCode"],
				],
			},
		],
		
		# http://apps.gs1.org/GDD/Pages/clDetails.aspx?semanticURN=urn:gs1:gdd:cl:ContactTypeCode&release=4
		# source_field => array of hashes: go down one level, expect an array
		["tradeItemContactInformation", [
				{
					# match => hash of key value conditions: assign values to field only if the conditions match
					match => [
						["contactTypeCode", "CXC"],
					],
					fields => [
						["contactName", "customer_service_fr"],
						["contactAddress", "+customer_service_fr"],
					],
				},
			],
		],
		
		["tradeItemInformation",
			{
				fields => [
					["productionVariantDescription", "sources_fields:org-gs1:productionVariantDescription, producer_version_id"],
					
					["extension", {
							fields => [
								["allergen_information:allergenInformationModule", {
										fields => [
											["allergenRelatedInformation", {
													fields => [
														["allergen", [
																{
																	match => [
																		["levelOfContainmentCode", "CONTAINS"],
																	],
																	fields => [
																		# source_field => +target_field' : add to field, separate with commas if field is not empty
																		# source_field => target_field%map_id : map the target value using the specified map_id
																		# (do not assign a value if there is no corresponding entry in the map)
																		['allergenTypeCode', '+allergens%allergenTypeCode'],
																	],
																},
																{
																	match => [
																		["levelOfContainmentCode", "MAY_CONTAIN"],
																	],
																	fields => [
																		# source_field => +target_field' : add to field, separate with commas if field is not empty
																		# source_field => target_field%map_id : map the target value using the specified map_id
																		# (do not assign a value if there is no corresponding entry in the map)
																		['allergenTypeCode', '+traces%allergenTypeCode'],
																	],
																},
															],
														],
														["isAllergenRelevantDataProvided", "sources_fields:org-gs1:isAllergenRelevantDataProvided"],
													],
												},
											],
										],
									},
								],
								
								["nutritional_information:nutritionalInformationModule", {
										fields => [
											["nutrientHeader"],	# nutrients are handled specially with specific code
										],
									},
								],
								
								["consumer_instructions:consumerInstructionsModule", {
										fields => [
											["consumerStorageInstructions", "conservation_conditions"],
										],
									}
								],
								
								["food_and_beverage_ingredient:foodAndBeverageIngredientModule", {
										fields => [
											["ingredientStatement", "ingredients_text"],
										],
									},
								],
								
								["nonfood_ingredient:nonfoodIngredientModule", {
										fields => [
											["nonfoodIngredientStatement", "ingredients_text"],
										],
									},
								],								
								
								["food_and_beverage_preparation_serving:foodAndBeveragePreparationServingModule", {
										fields => [
											["preparationServing", {
													fields => [
														["preparationInstructions", "preparation"],
													],
												},
											],
										],
									},
								],
								
								["health_related_information:healthRelatedInformationModule", {
										fields => [
											["healthRelatedInformation", {
													match => [
														["nutritionalProgramCode","8"],
													],
													fields => [
														["nutritionalScore", "nutriscore_grade_producer"],
													],
												},
											],
										],
									},
								],
							
								["packaging_information:packagingInformationModule", {
										fields => [
											["packaging", {
													fields => [
														["packagingTypeCode", "+packaging%packagingTypeCode"],
													],
												},
											],
										],
									},
								],							
								
								["packaging_marking:packagingMarkingModule", {
										fields => [
											["packagingMarking", {
													fields => [
														# the source can be an array if there are multiple labels
														["packagingMarkedLabelAccreditationCode", "+labels%packagingMarkedLabelAccreditationCode"],
													],
												},
											],
										],
									},
								],
								
								["referenced_file_detail_information:referencedFileDetailInformationModule", {
										fields => [
											["referencedFileHeader",  [
													{
														match => [
															["isPrimaryFile", "TRUE"],
														],
														fields => [
															["uniformResourceIdentifier", "image_front"],
														],
													},
													{
														does_not_match => [
															["isPrimaryFile", "TRUE"],
														],
														fields => [
															["uniformResourceIdentifier", "+image_other"],
														],
													},
												],
											],
										],
									},
								],								
								
								["trade_item_description:tradeItemDescriptionModule", {
										fields => [
											["tradeItemDescriptionInformation", {
													fields => [
														["descriptionShort", "abbreviated_product_name"],
														["functionalName", "+categories_if_match_in_taxonomy"],
														["regulatedProductName", "generic_name"],
														["tradeItemDescription", "product_name"],
														["brandNameInformation", {
																fields => [
																	['brandName' => '+brands'],
																	['subBrand' => '+brands'],
																],
															},
														],
													],
												},
											],
										],
									},
								],
								
								["trade_item_measurements:tradeItemMeasurementsModule", {
										fields => [
											["tradeItemMeasurements", {
													fields => [
														["netContent", "quantity"],
														["tradeItemWeight", {
																fields => [
																	["netWeight", "net_weight"],
																],
															},
														],
													],
												},
											],
										],
									},
								],								
								
								["trade_item_lifespan:tradeItemLifespanModule", {
										fields => [
											["tradeItemLifespan", {
													fields => [
														# the source can be an array if there are multiple labels
														["itemPeriodSafeToUseAfterOpening", "+periods_after_opening"],
													],
												},
											],
										],
									},
								],
							],
						},
					],
				],
			},
		],
		
		["tradeItemSynchronisationDates", {
				fields => [
					["publicationDateTime", "sources_fields:org-gs1:publicationDateTime"],
				],
			},
		],
	],
);


=head1 FUNCTIONS

=head2 init_csv_fields ()

%seen_fields and @fields are used to output the fields in the order of the GS1 to OFF mapping configuration

=cut

my %seen_csv_fields = ();
my @csv_fields = ();

sub init_csv_fields() {

	%seen_csv_fields = ();
	@csv_fields = ();	
}


=head2 assign_field ( $results_ref $target_field $target_value)

Used to assign a value to a field, and keep track of the order of the fields.

=cut

sub assign_field($$$) {

	my $results_ref = shift;
	my $target_field = shift;
	my $target_value = shift;
	
	$results_ref->{$target_field} = $target_value;
	
	if (not defined $seen_csv_fields{$target_field}) {
		push @csv_fields, $target_field;
		$seen_csv_fields{$target_field} = 1;
	}
}


=head2 gs1_to_off ($gs1_to_off_ref, $json_ref, $results_ref)

Recursive function to go through all first level keys of the $gs1_to_off_ref mapping.
All values that can be assigned at that level are assigned, and if we need to go into a nested level,
the function calls itself again.

=head3 Arguments

=head4 $gs1_to_off_ref - Mapping configuration from GS1 to off for the current level

=head4 $json_ref - JSON structure for the current level

=head4 $results_ref - Hash of key / value pairs to store the complete output of the mapping

The same hash reference is passed to recursive calls to the gs1_to_off function.

=cut


sub gs1_to_off;

sub gs1_to_off ($$$) {
	
	my $gs1_to_off_ref = shift;
	my $json_ref = shift;
	my $results_ref = shift;
	
	$log->debug("gs1_to_off", { json_ref_keys => [sort keys %$json_ref] }) if $log->is_debug();
	
	# Check the matching conditions if any
	
	if (defined $gs1_to_off_ref->{match}) {
		
		$log->debug("gs1_to_off - checking conditions", { match => $gs1_to_off_ref->{match} } ) if $log->is_debug();
	
		foreach my $match_field_ref (@{$gs1_to_off_ref->{match}}) {
			
			my $match_field = $match_field_ref->[0];
			my $match_value = $match_field_ref->[1];
			
			if ((not defined $json_ref->{$match_field})
				or ($json_ref->{$match_field} ne $match_value)) {
									
				$log->debug("gs1_to_off - condition does not match",
					{	match_field => $match_field,
						match_value => $match_value,
						actual_value => $json_ref->{$match_field} }) if $log->is_debug();
				
				return;
			}	
		}
		
		$log->debug("gs1_to_off - conditions match") if $log->is_debug();
	}
	
	if (defined $gs1_to_off_ref->{does_not_match}) {
		
		$log->debug("gs1_to_off - checking conditions", { does_not_match => $gs1_to_off_ref->{does_not_match} } ) if $log->is_debug();
		
		my $match = 1;
	
		foreach my $match_field_ref (@{$gs1_to_off_ref->{does_not_match}}) {
			
			my $match_field = $match_field_ref->[0];
			my $match_value = $match_field_ref->[1];
			
			if ((not defined $json_ref->{$match_field})
				or ($json_ref->{$match_field} ne $match_value)) {
									
				$log->debug("gs1_to_off - condition does not match",
					{	match_field => $match_field,
						match_value => $match_value,
						actual_value => $json_ref->{$match_field} }) if $log->is_debug();
				
				$match = 0;
				last;
			}	
		}
		
		return if $match;
		
		$log->debug("gs1_to_off - conditions match") if $log->is_debug();
	}	
		
	$log->debug("gs1_to_off - assigning fields") if $log->is_debug();
	
	# If the conditions match, assign the fields

	foreach my $source_field_ref (@{$gs1_to_off_ref->{fields}}) {
		
		my $source_field = $source_field_ref->[0];
		my $source_target = $source_field_ref->[1];
		
		$log->debug("gs1_to_off - source fields", { source_field => $source_field }) if $log->is_debug();
		
		if (defined $json_ref->{$source_field}) {
			
			$log->debug("gs1_to_off - existing source fields",
				{ source_field => $source_field, ref => ref($source_target) }) if $log->is_debug();
		
			# if the source field is nutrientHeader, we need to extract multiple
			# nutrition facts tables (for unprepared and prepared product)
			# with multiple nutrients.
			# As the mapping is complex, it is done with special code below
			# instead of the generic matching code.
			
			if ($source_field eq "nutrientHeader") {
				
				$log->debug("gs1_to_off - special handling for nutrientHeader array") if $log->is_debug();
				
				foreach my $nutrient_header_ref (@{$json_ref->{$source_field}}) {
					
					my $type = "";
					
					if ($nutrient_header_ref->{preparationStateCode} eq "PREPARED") {
						$type = "_prepared";
					}
					
					my $serving_size_value;
					my $serving_size_unit;
					my $serving_size_description;
					my $serving_size_description_lc;
					
					if (defined $nutrient_header_ref->{servingSize}{'#'}) {
						$serving_size_value = $nutrient_header_ref->{servingSize}{'#'};
						$serving_size_unit = $gs1_maps{measurementUnitCode}{$nutrient_header_ref->{servingSize}{'@'}{measurementUnitCode}};
					}
					elsif (defined $nutrient_header_ref->{servingSize}{'$t'}) {
						$serving_size_value = $nutrient_header_ref->{servingSize}{'$t'};
						$serving_size_unit = $gs1_maps{measurementUnitCode}{$nutrient_header_ref->{servingSize}{measurementUnitCode}};
					}
					else {
						$log->error("gs1_to_off - unrecognized serving size",
									{ servingSize => $nutrient_header_ref->{servingSize} }) if $log->is_error();
					}
					
					if (defined $nutrient_header_ref->{servingSizeDescription}) {
						if (defined $nutrient_header_ref->{servingSizeDescription}{'#'}) {
							$serving_size_description = $nutrient_header_ref->{servingSizeDescription}{'#'};
							$serving_size_description_lc = $nutrient_header_ref->{servingSizeDescription}{'@'}{languageCode};
						}
						elsif (defined $nutrient_header_ref->{servingSizeDescription}{'$t'}) {
							$serving_size_description = $nutrient_header_ref->{servingSizeDescription}{'$t'};
							$serving_size_description_lc = $nutrient_header_ref->{servingSizeDescription}{languageCode};
						}
					}
					
					my $per = "100g";
					
					if ((defined $serving_size_value) and ($serving_size_value != 100)) {
						$per = "serving";
						$serving_size_value += 0;	# remove extra .0
						
						my $extra_serving_size_description = "";
						if ((defined $serving_size_description) and (defined $serving_size_description_lc)) {
							$extra_serving_size_description = ' (' . $serving_size_description . ')';
						}
						
						assign_field($results_ref, "serving_size", $serving_size_value . " " . $serving_size_unit . $extra_serving_size_description);
					}
					
					if (defined $nutrient_header_ref->{nutrientDetail}) {
						foreach my $nutrient_detail_ref (@{$nutrient_header_ref->{nutrientDetail}}) {
							my $nid = $gs1_maps{nutrientTypeCode}{$nutrient_detail_ref->{nutrientTypeCode}};
							
							if (defined $nid) {
								my $nutrient_field = $nid . $type . "_" . $per;
								
								my $nutrient_value;
								my $nutrient_unit;
								
								# quantityContained may be an array with a single hash
								if ((defined $nutrient_detail_ref->{quantityContained}) and (ref($nutrient_detail_ref->{quantityContained}) eq "ARRAY")) {
									$nutrient_detail_ref->{quantityContained} = $nutrient_detail_ref->{quantityContained}[0];
								}
								
								if (defined $nutrient_detail_ref->{quantityContained}{'#'}) {
									$nutrient_value = $nutrient_detail_ref->{quantityContained}{'#'};
									$nutrient_unit = $gs1_maps{measurementUnitCode}{$nutrient_detail_ref->{quantityContained}{'@'}{measurementUnitCode}};
								}
								elsif (defined $nutrient_detail_ref->{quantityContained}{'$t'}) {
									$nutrient_value = $nutrient_detail_ref->{quantityContained}{'$t'};
									$nutrient_unit = $gs1_maps{measurementUnitCode}{$nutrient_detail_ref->{quantityContained}{measurementUnitCode}};
								}
								else {
									$log->error("gs1_to_off - unrecognized quantity contained",
												{ quantityContained => $nutrient_detail_ref->{quantityContained} }) if $log->is_error();
								}
								
								# less than < modifier
								if ((defined $nutrient_detail_ref->{measurementPrecisionCode})
									and ($nutrient_detail_ref->{measurementPrecisionCode} eq "LESS_THAN")) {
									$nutrient_value = "< " . $nutrient_value;
								}
								
								# energy: based on the nutrient unit, assign the energy-kj or energy-kcal field
								if ($nid eq "energy") {
									if ($nutrient_unit eq "kcal") {
										$nutrient_field = "energy-kcal" . $type . "_" . $per;
									}
									else {
										$nutrient_field = "energy-kj" . $type . "_" . $per;
									}
								}
								
								assign_field($results_ref, $nutrient_field . "_value", $nutrient_value);
								assign_field($results_ref, $nutrient_field . "_unit", $nutrient_unit);
							}
							else {
								$log->error("gs1_to_off - unrecognized nutrient",
									{ nutrient_detail_ref => $nutrient_detail_ref }) if $log->is_error();
							}
						}
					}
				}
			}
		
			# If the value is a scalar, it is a target field (or multiple target fields)			
			elsif (ref($source_target) eq "") {
				
				$log->debug("gs1_to_off - source field directly maps to target field",
						{ source_field => $source_field, target_field => $source_target }) if $log->is_debug();
						
				# We may have multiple source values, in an array
				
				my @source_values;
				
				if (ref($json_ref->{$source_field}) eq "ARRAY") {
					@source_values = @{$json_ref->{$source_field}};
				}
				else {
					@source_values = ($json_ref->{$source_field});
				}
				
				foreach my $source_value (@source_values) {
				
					# We may have multiple target fields, separated by commas
					foreach my $target_field (split(/\s*,\s*/, $source_target)) {
						
						$log->debug("gs1_to_off - assign value to target field",
							{ source_field => $source_field, source_value => $source_value, target_field => $target_field }) if $log->is_debug();
							
						# Some fields indicate a language:
						
	# ingredientStatement: {
	#   languageCode: "fr",
	#   $t: "Ingrédients: LAIT entier en poudre (38,9%), PETIT-LAIT filtré en poudre, café soluble (8,0%), fibres de chicorée (oligofructose) (8%), chicorée soluble (7,5%), stabilisant : E331, correcteur d'acidité : E340, sulfate de magnésium."
	# },

						# or another format (depending on how the XML was converted to JSON):
						
	# ingredientStatement: {
	#   #: "Ingrédients: LAIT entier en poudre (38,9%), PETIT-LAIT filtré en poudre, café soluble (8,0%), fibres de chicorée (oligofructose) (8%), chicorée soluble (7,5%), stabilisant : E331, correcteur d'acidité : E340, sulfate de magnésium.",
	#   @: {
	#     languageCode: "fr"
	#   }
	# },

						if (ref($source_value) eq "HASH") {
							my $language_code;
							my $value;
							
							# There may be a language code
							if (defined $source_value->{languageCode}) {
								$language_code = $source_value->{languageCode};
							}
							elsif ((defined $source_value->{'@'}) and (defined $source_value->{'@'}{languageCode})) {
								$language_code = $source_value->{'@'}{languageCode};
							}
							
							# Keep track of language codes so that we can assign the lc and lang fields
							if (defined $language_code) {
								defined $results_ref->{languages} or $results_ref->{languages} = {};
								defined $results_ref->{languages}{$language_code} or $results_ref->{languages}{$language_code} = 0;
								$results_ref->{languages}{$language_code}++;
							}
							
							if (defined $source_value->{'$t'}) {
								$value = $source_value->{'$t'};
							}
							elsif (defined $source_value->{'#'}) {
								$value = $source_value->{'#'};
							}
							
							# There may be a measurement unit code, or a time measurement unit code
							# in that case, concatenate it to the value
							
							foreach my $code ("measurementUnitCode", "timeMeasurementUnitCode") {
							
								if (defined $source_value->{$code}) {
									$value .= " " . $gs1_maps{$code}{$source_value->{$code}};
								}
								elsif ((defined $source_value->{'@'}) and (defined $source_value->{'@'}{$code})) {
									$value .= " " . $gs1_maps{$code}{$source_value->{'@'}{$code}};
								}
							}
							
							# If the field is a language specific field, we can assign the value to the language specific field
							if ((defined $language_code) and (defined $language_fields{$target_field})) {
								$target_field = $target_field . "_" . lc($language_code);
								$log->debug("gs1_to_off - changed to language specific target field",
									{ source_field => $source_field, source_value => $source_value, target_field => $target_field }) if $log->is_debug();
							}
							
							if (defined $value) {
								$source_value = $value;
							}
							else {
								$log->error("gs1_to_off - issue with source value structure",
									{ source_field => $source_field, source_value => $source_value, target_field => $target_field }) if $log->is_error();
								$source_value = undef;
							}
						}
						
						if ((defined $source_value) and ($source_value ne "")) {
							
							# allergenTypeCode => '+traces%allergens',
							# % sign means we will use a map to transform the source value
							if ($target_field =~ /\%/) {
								$target_field = $`;
								my $map = $';
								if (defined $gs1_maps{$map}{$source_value}) {
									$source_value = $gs1_maps{$map}{$source_value};
								}
								else {
									$log->error("gs1_to_off - unknown source value for map",
										{ source_field => $source_field, source_value => $source_value, target_field => $target_field, map => $map }) if $log->is_error();
									defined $unknown_entries_in_gs1_maps{$map} or $unknown_entries_in_gs1_maps{$map} = {};
									defined $unknown_entries_in_gs1_maps{$map}{$source_value} or $unknown_entries_in_gs1_maps{$map}{$source_value} = 0;
									$unknown_entries_in_gs1_maps{$map}{$source_value}++;
								}
							}							
						
							# allergenTypeCode => '+traces%allergens',
							# + sign means we will create a comma separated list if we have multiple values
							if ($target_field =~ /^\+/) {
								$target_field = $';
								
								if (defined $results_ref->{$target_field}) {
									$source_value = $results_ref->{$target_field} . ', ' . $source_value;
								}
							}
							
							assign_field($results_ref, $target_field, $source_value);
						}
					}
					
				}
			}
			
			elsif (ref($source_target) eq "ARRAY") {
				
#	http://apps.gs1.org/GDD/Pages/clDetails.aspx?semanticURN=urn:gs1:gdd:cl:ContactTypeCode&release=4
#	source_field => array of hashes: go down one level, expect an array
#	
#		["tradeItemContactInformation", [
#				{
#					# match => hash of key value conditions: assign values to field only if the conditions match
#					match => [
#						["contactTypeCode", "CXC"],
#					],
#					fields => [
#						["contactAddress", "customer_service_fr"],
#					],
#				},
#			],
#		],		
	
				$log->debug("gs1_to_off - array field", { source_field => $source_field }) if $log->is_debug();
	
				# Loop through the array entries of the GS1 to OFF mapping
				
				foreach my $gs1_to_off_array_entry_ref (@{$source_target}) {
					
					# Loop through the array entries of the JSON file
					
					# If the source file is not an array, create it
					# (e.g. if only one element is there, the xml to json conversion might not create an array)
					if (ref($json_ref->{$source_field}) ne "ARRAY") {
						$json_ref->{$source_field} = [ $json_ref->{$source_field} ];
					}
							
					foreach my $json_array_entry_ref (@{$json_ref->{$source_field}}) {

						gs1_to_off($gs1_to_off_array_entry_ref, $json_array_entry_ref, $results_ref);
					}
				}
			}			
			
			elsif (ref($source_target) eq "HASH") {
				
				# Go down one level
				
				# The source structure may be a hash or an array of hashes
				# e.g. Equadis: allergenRelatedInformation is a hash, CodeOnline: it is an array
				
				if (ref($json_ref->{$source_field}) eq "HASH") {
				
					gs1_to_off($source_target, $json_ref->{$source_field}, $results_ref);
				}
				elsif (ref($json_ref->{$source_field}) eq "ARRAY") {
					foreach my $json_array_entry_ref (@{$json_ref->{$source_field}}) {

						gs1_to_off($source_target, $json_array_entry_ref, $results_ref);
					}
				}
			}
		}
	}
}


=head2 convert_gs1_json_to_off_csv_fields ($json)

Thus function converts the data for one product in the GS1 format converted to JSON.
GS1 format is in XML, it needs to be transformed to JSON with xml2json first.
In some cases, the conversion to JSON has already be done by a third party (e.g. the CodeOnline database from GS1 France).

=head3 Arguments

=head4 json text

=head3 Return value

=head4 Reference to a hash of fields

The function returns a reference to a hash.

Each key is the name of the OFF csv field, and it is associated with the corresponding value for the product.

=cut

sub convert_gs1_json_to_off_csv($) {

	my $json = shift;
	
	my $json_ref = decode_json($json);
	
	# The JSON can contain only the product information "tradeItem" level
	# or the tradeItem can be encapsulated in a message
	
	# catalogue_item_notification:catalogueItemNotificationMessage
	# - transaction
	# -- documentCommand
	# --- catalogue_item_notification:catalogueItemNotification
	# ---- catalogueItem
	# ----- tradeItem
	
	foreach my $field (qw(
		catalogue_item_notification:catalogueItemNotificationMessage
		transaction
		documentCommand
		catalogue_item_notification:catalogueItemNotification
		catalogueItem
		tradeItem)) {
		if (defined $json_ref->{$field}) {
			$json_ref = $json_ref->{$field};
			$log->debug("convert_gs1_json_to_off_csv - remove encapsulating field", { field => $field }) if $log->is_debug();
		}
	}
	
	if (not defined $json_ref->{gtin}) {
		
		$log->debug("convert_gs1_json_to_off_csv - no gtin - skipping", { json_ref => $json_ref }) if $log->is_debug();
		return {};
	}
	
	if ((not defined $json_ref->{isTradeItemAConsumerUnit}) or ($json_ref->{isTradeItemAConsumerUnit} ne "true")) {
		$log->debug("convert_gs1_json_to_off_csv - isTradeItemAConsumerUnit not true - skipping", 
			{ isTradeItemAConsumerUnit => $json_ref->{isTradeItemAConsumerUnit} }) if $log->is_debug();
		return {};
	}
	
	my $results_ref = {};
	
	gs1_to_off(\%gs1_to_off, $json_ref, $results_ref);
	
	# assign the lang and lc fields
	if (defined $results_ref->{languages}) {
		my @sorted_languages = sort ( { $results_ref->{languages}{$b} <=> $results_ref->{languages}{$a} } keys %{$results_ref->{languages}});
		my $top_language = $sorted_languages[0];
		$results_ref->{lc} = $top_language;
		$results_ref->{lang} = $top_language;
		delete $results_ref->{languages};
	}
	
	return $results_ref;
}


=head2 read_gs1_json_file ($json_file, $products_ref)

Read a GS1 file on json format, convert it to the OFF format, return the
result, and store the result in the $products_ref array (if not undef)

=head3 Arguments

=head4 input json file path and name $json_file

=head4 reference to output products array $products_ref

=cut

sub read_gs1_json_file($$) {
	
	my $json_file = shift;
	my $products_ref = shift;
	
	$log->debug("read_gs1_json_file", { json_file => $json_file }) if $log->is_debug();
	
	open (my $in, "<", $json_file) or die("Cannot open json file $json_file : $!\n");
	my $json = join (q{}, (<$in>));
	close($in);
		
	my $results_ref = convert_gs1_json_to_off_csv($json);
	
	if ((defined $products_ref) and (defined $results_ref->{code})) {
		push @$products_ref, $results_ref;
	}
	
	return $results_ref;
}


=head2 write_off_csv_file ($csv_file, $products_ref)

Write all product data from the $products_ref array to a CSV file in OFF format.

=head3 Arguments

=head4 output CSV file path and name

=head4 reference to output products array $products_ref

=cut

sub write_off_csv_file($$) {
	
	my $csv_file = shift;
	my $products_ref = shift;
	
	$log->debug("write_off_csv_file", { csv_file => $csv_file }) if $log->is_debug();
	
	open(my $filehandle, ">:encoding(UTF-8)", $csv_file) or die("Cannot write csv file $csv_file : $!\n");
	
	my $separator = "\t";
	
	my $csv = Text::CSV->new ( { binary => 1 , sep_char => $separator } )  # should set binary attribute.
		or die "Cannot use CSV: ".Text::CSV->error_diag ();

	# Print the header line with fields names
	
	$log->debug("write_off_csv_file - header", { csv_fields => \@csv_fields }) if $log->is_debug();
	
	$csv->print ($filehandle, \@csv_fields);
	print $filehandle "\n";
	
	foreach my $product_ref (@$products_ref) {
		
		$log->debug("write_off_csv_file - product", { code => $product_ref->{code} }) if $log->is_debug();
		
		my @csv_fields_values = ();
		foreach my $field (@csv_fields) {
			push @csv_fields_values, $product_ref->{$field};
		}
		
		$csv->print ($filehandle, \@csv_fields_values);
		print $filehandle "\n";
	}
	
	close $filehandle;
}


=head2 print_unknown_entries_in_gs1_maps ()

Prints the entries for GS1 data types for which we do not have a corresponding OFF match,
ordered by the number of occurences in the GS1 data

=cut

sub print_unknown_entries_in_gs1_maps() {
	
	my $unknown_entries = 0;
	
	foreach my $map (sort keys %unknown_entries_in_gs1_maps) {
		print "$map map has unknown entries:\n";
		
		foreach my $source_value
			(sort { $unknown_entries_in_gs1_maps{$map}{$a} <=> $unknown_entries_in_gs1_maps{$map}{$b} }
				keys %{$unknown_entries_in_gs1_maps{$map}}) {
			print $source_value . "\t" . $unknown_entries_in_gs1_maps{$map}{$source_value} . "\n";
			$unknown_entries++;
		}
		
		print "\n";
	}
	
	return $unknown_entries;
}

1;

