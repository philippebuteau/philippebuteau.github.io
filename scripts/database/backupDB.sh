#!/bin/bash

# Flags pour automatisation
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--database) item="$2";     shift 2 ;;
        -t|--table)    table="$2";    shift 2 ;;
        -o|--options)  tags="$2";     shift 2 ;;
        -c|--cleanup)  clean="Y";	  shift 1 ;;
        -h|--help)
			echo ""
			echo "Mysql Database Manager"
			echo ""
			echo "Automation flags: "
			echo "-c | --cleanup"
			echo "-d | --database"
			echo "-t | --table"
			echo "-o | --options"
			echo ""
			echo "Available options: "
			echo "--defaults-file, --single-transaction, --triggers, --quick, --events, --no-data, --no-create-info, --add-drop-table, --where='condition', --routines, --lock-tables"
            echo ""
            echo "Usage A (auto-backup) : backup -d database -t table -o '--optionA --optionb'"
            echo "Usage B (auto-cleanup): backup -c"
            echo "Usage C (manual mode) : backup"
            echo ""
            exit
            ;;
        *)
            echo "Unknown option: $1"
            exit
            ;;
    esac
done

# Check for automation flags
echo ""
if [[ -n $item ]]; then
	switch_database=1
	echo "Automation flag detected: Database=${item}"
fi

if [[ -n $table ]]; then
	switch_table=1
	echo "Automation flag detected: table=${table}"
fi

if [[ -n $tags ]]; then
	switch_options=1
	echo "Automation flag detected: options=${tags}"
fi

if [[ -n $clean ]]; then
	switch_cleanup=1
	echo "Automation flag detected: cleanup=${clean}"
fi

# Source .bashrc pour CRON - a remplacer par un fichier d'environement
source /home/admin/.bashrc
numberToKeep=3
#PW=$(echo "$encrypted_pw" | openssl enc -aes-256-cbc -a -d -pbkdf2 -pass file:${HOME}/.myKeys/mysqlKey)

liste_DB=$(mysql -e "SHOW DATABASES" -B -N)
date_heure=$(date +"%Y-%m-%d-%H%M%S")
dossier_backup="/backups/DB"
file="${date_heure}.sql"
userCmd="USE mysql; SELECT user,host FROM user WHERE user NOT LIKE 'mysql%' AND user != 'root' ORDER BY user;"

#Text variables
BOLD=$'\e[1m'
RESET=$'\e[0m'
ACCENT=$'\e[96m'
RED=$'\e[31m'
GREEN=$'\e[32m'


function show_databases() {
	liste_DB=$(mysql -e "SHOW DATABASES" -B -N)
	echo ""
	echo -e "${BOLD}Databases: ${RESET}"
	echo ""
	echo "$liste_DB"
	echo ""
	if [[ -z "$bypass1" ]]; then
		read -p "Appuyez sur ENTER pour continuer"
	fi
}

function delete_database() {
	liste_DB=$(mysql -e "SHOW DATABASES" -B -N)
	echo ""
	echo -e "${BOLD}Databases: ${RESET}"
	echo ""
	echo "$liste_DB"
	echo ""
	
	echo -e "${BOLD}Entrez une base de donnees a supprimer:  ${RESET}"
	read DB
	if [[ -n "$DB" ]]; then
		mysql -e "DROP DATABASE ${DB}"
		echo -e "${BOLD}Database supprime: ${DB}${RESET}"
	fi
	read -p "Appuyez sur ENTER pour continuer"
}

function show_tables() {
	bypass1=1
	echo ""
	show_databases
	echo ""
	echo -e "${BOLD}Entrez le nom de la base de donnees a analyser: ${RESET}"
	read DB
	echo ""
	mysql -e "USE ${DB}; SHOW TABLES;"
	echo ""
	if [[ -z "$bypass2" ]]; then
		read -p "Appuyez sur ENTER pour continuer"
	fi
}

function show_data() {
	bypass2=1
	show_tables
	echo ""
	echo -e "${BOLD}Entrez le nom de la table a analyser: ${RESET}"
	read table
	echo -e "${BOLD}TABLE: ${table}${RESET}"
	mysql -e "USE ${DB}; SELECT * FROM ${table};"
	echo ""

	read -p "Appuyez sur ENTREE pour continuer"	
}

# Fonction pour executer le backup de l'item courrant
function bckp() {
	if [ -e "$dossier_backup" ]; then
	
		# Ajouter la table si elle est specifiee
		if [[ -n "$table" ]]; then
			nom="${item}.${table}"
		else
			nom="$item"
		fi
		
		# Ajouter un tag dans le nom du backup
		if [[ -n "$tags" ]]; then
			# Schema only
			if [[ "$tags" == *"--no-data"* ]]; then
				nom="${nom}.SCHEMA"
			fi
			# Data only
			if [[ "$tags" == *"--no-create-info"* ]]; then
				nom="${nom}.DATA"
			fi
			
			# Convert options to array
			read -r -a tags_array <<< "$tags"		
		fi
		
		# Nom complet du fichier courrant
		current_file="${dossier_backup}/${nom}_${file}"
		
		# mysqldump
		if [[ -n "$table" ]];then
			# Ajouter les options si elles sont specifiees
			if [[ -n "$tags" ]]; then
				mysqldump "${tags_array[@]}" "$item" "$table" > "$current_file"
			else
				mysqldump "$item" "$table" > "$current_file"
			fi
		else
			# Ajouter les options si elles sont specifiees
			if [[ -n "$tags" ]]; then
				mysqldump "${tags_array[@]}" "$item" > "$current_file"
			else
				mysqldump "$item" > "$current_file"
			fi
		fi
		
		if [[ "$encrypt" == [yY] ]]; then
			# Chiffrement avec 7zip et un mot de passe
			7z a "$current_file".7z "$current_file" -p"$PW" -sdel
			echo -e "${BOLD}Fichier enregistre: ${current_file}.7z${RESET}"
		else
			echo -e "${BOLD}Fichier enregistre: ${current_file}${RESET}"
		fi
		
	else
		echo -e "${RED}${BOLD}Le dossier $dossier_backup n'existe pas.${RESET}"
	fi
}

# Fonction pour specifier une table avec la database
function add_table() {
	
	echo -e "${BOLD}Souhaitez-vous specifier une table pour cette base de donnees (y/N): ${RESET}"
	read confirm
	
	if [[ "$confirm" == [yY] ]]; then
		mysql -e "USE ${item}; SHOW TABLES" -B -N
		echo -e "${BOLD}Choisir une table: ${RESET}"
		read table
	else
		table=""
	fi	
}

# Fonction pour specifier des options pour le backup
function add_tags() {
	echo ""
	echo "--defaults-file, --single-transaction, --triggers, --quick, --events, --no-data, --no-create-info, --add-drop-table, --where='condition', --routines, --lock-tables"
	echo ""
	echo -e "${BOLD}Specifiez les options pour cette operation: ${RESET}"
	read tags
}

# Fonction pour dumper une seule DB ou pour l'execution automatique
function bckp_soloDB() {
	
	if [[ -z $switch_database && -z $switch_table && -z $switch_options ]]; then
		echo "===================================================="
		echo -e "==============     ${BOLD}Liste des DB${RESET}     ================"
		echo "===================================================="
		echo "$liste_DB"
		echo "===================================================="
		echo -e "${BOLD}Choisir une DB a sauvegarder : ${RESET}"
		read item
		echo "===================================================="
		
		add_table # Call add_table function
		add_tags # Call add_tags function
	fi
	
	bckp # Call bckp function
	
	if [[ -z $switch_database && -z $switch_table && -z $switch_options ]]; then
		read -p "Appuyez sur ENTREE pour continuer"
	fi
}

function restore_DB() {
	bypass1=1
	echo ""
	show_databases
	echo ""
	echo -e "${BOLD}Entrez le nom de la base de donnees a restaurer: ${RESET}"
	read focusOn
	echo ""
	
	echo "===================================================="
	echo -e "===========     ${BOLD}Liste des fichiers${RESET}     ============="
	echo "===================================================="
	ls -l "$dossier_backup" | grep "$focusOn"
	echo "===================================================="
	echo -e "${BOLD}Choisir une sauvegarde a restaurer : ${RESET}"
	read file
	echo "===================================================="

	# Archive file path
	archive="${dossier_backup}/${file}"
	echo "SOURCE ARCHIVE : ${archive}"

	# No extension
	filename=$(basename "$file")
	
	# Check if DATA only archive
	isdata=0
	[[ "$filename" == *DATA* ]] && isdata=1
	echo "IS DATA ONLY: ${isdata}"
	
	# Trim Date/Time and DATA/SCHEMA tags
	name="${filename%%_*}"
	name="${name//.DATA/}"
	name="${name//.SCHEMA/}"
	
	# Extract database and table if specified
	if [[ "$name" == *.* ]]; then
		database="${name%%.*}"
		table="${name#*.}"
	else
		database="$name"
		table=""	
	fi
	
	# Display filtering results
	echo "DATABASE: ${database} | TABLE : ${table}"
	
	# Create database it doesn't exist
	mysql -e "CREATE DATABASE IF NOT EXISTS ${database}"
	
	# Clear data if archive is data only
	if [[ "$isdata" == 1 ]]; then
		if [[ -z "$table" ]]; then
			for i in $(mysql -e "USE ${database}; SHOW TABLES;" -B -N); do
				mysql -e "USE ${database}; SET FOREIGN_KEY_CHECKS = 0; TRUNCATE TABLE ${i}; SET FOREIGN_KEY_CHECKS = 1;"
			done
		else
			mysql -e "USE ${database}; SET FOREIGN_KEY_CHECKS = 0; TRUNCATE TABLE ${table}; SET FOREIGN_KEY_CHECKS = 1;"
		fi
	fi
	
	# Restore encrypted archive to database
	7z x "${archive}" -so -p"$PW" | mysql "$database"
	read -p "Appuyez sur ENTREE pour continuer"
}


# Fonctions de nettoyage
function cleanup_dumps() {
	echo ""
	
	# Creation d'un dictionnaire nomDeSauvegarde -> fichiersCorrespondants
	declare -A dumps
	
	for file in "$dossier_backup"/*; do
		name=$(basename "$file")
		db=${name%%_*}
		dumps["$db"]+=$'\n'"$file"
	done
	
	# Pour chaque nomDeSauvegarde
	for key in "${!dumps[@]}"; do
	
		# Cree un tableau avec les fichiers correspondants
		mapfile -t dump_list <<< "${dumps[$key]}"
		# Compte des fichiers correspondants
		count=${#dump_list[@]}
		count=$(($count-1))
		
		echo ""
		echo -e "${BOLD}${key} -> ${count} sauvegardes${RESET}"
		
		# Si un nombre a conserver n'est pas specifie
		if [[ -z $numberToKeep ]]; then
			echo -e "${BOLD}Combien de sauvegardes souhaitez-vous conserver: ${RESET}"
			read -r numberToKeep
		fi
		
		# Pour chaque fichier correspondant
		i=1
		for dump in "${dump_list[@]}"; do
			# Skip iteration si dump est vide
			if [[ -z $dump ]]; then
				continue
			fi

			# Tant que i est plus petit ou egal au compte total - nombre a conserver -> supprime (Les fichiers sont ordones par noms, donc du plus vieux au plus recent)
			if (( i <= count - numberToKeep )); then
				echo "${RED}DELETE: ${dump}${RESET}"
				if [[ $dryrun == "false" ]]; then
					rm -f "$dump"
				fi
			else
				echo "${GREEN}KEEP:   ${dump}${RESET}"
			fi

			((i++))
		done
	done
	
	if [[ -z $switch_cleanup ]]; then
		read -p "Appuyez sur ENTREE pour continuer"
	fi
}

#####################################################################
########## Fonctions de Gestion d'utilisateurs et de roles###########
#####################################################################

function show_users() {
	#Affichage
	clear
	echo ""
	echo -e "${BOLD}Liste des utilisateurs${RESET}"
	echo ""
	mysql -e "$userCmd"
	echo ""
}

function show_grants() {
	show_users
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		echo -e "${BOLD}Entrez le type d'utilisateur a affecter (user/role): ${RESET}"
		read entity_type
		echo -e "${BOLD}Entrez le nom de l'utilisateur ou role a analyser: ${RESET}"
		read user
		
		if [[ $entity_type == "user" ]]; then
			echo -e "${BOLD}Entrez le nom de l'hote de l'utilisateur: ${RESET}"
			read host
			mysql -e "SHOW GRANTS FOR '${user}'@'${host}';"
		elif [[ $entity_type == "role" ]]; then
			mysql -e "SHOW GRANTS FOR '${user}';"
		fi
		
		echo -e "${BOLD}Souhaitez-vous afficher pour un autre utilisateur (y/N) :${RESET}"
		read loop		
	done
}

function create_role() {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Creation de roles${RESET}"
		echo ""
		#Utilitaire	
		echo -e "${BOLD}Entrez le nom du role a ajouter: ${RESET}"
		read role
		mysql -e "CREATE ROLE ${role};"
		
		echo -e "${BOLD}Souaithez-vous ajouter un autre role (y/N) :${RESET}"
		read loop
	done
}

function drop_role() {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Suppression de roles${RESET}"
		echo ""
		
		#Utilitaire
		echo -e "${BOLD}Entrez le nom du role a supprimer: ${RESET}"
		read role
		mysql -e "DROP ROLE ${role};"
		
		echo -e "${BOLD}Souaithez-vous supprimer un autre role (y/N) :${RESET}"
		read loop
	done
}

function create_user() {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Creation d'utilisateurs${RESET}"
		echo ""
		
		#Utilitaire
		echo -e "${BOLD}Entrez le nom de l'utilisateur a ajouter: ${RESET}"
		read user
		echo -e "${BOLD}Entrez l'hote cet l'utilisateur: ${RESET}"
		read host
		echo -e "${BOLD}Entrez un mot de passe: ${RESET}"
		read -s passwd
		mysql -e "CREATE USER '${user}'@'${host}' IDENTIFIED BY '${passwd}';"
		
		echo -e "${BOLD}Souhaitez-vous creer un autre utilisateur (y/N) :${RESET}"
		read loop
	done
}

function drop_user() {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Suppression d'utilisateurs${RESET}"
		echo ""
		
		#Utilitaire
		echo -e "${BOLD}Entrez le nom de l'utilisateur a supprimer: ${RESET}"
		read user
		echo -e "${BOLD}Entrez l'hote cet l'utilisateur: ${RESET}"
		read host
		mysql -e "DROP USER '${user}'@'${host}';"
		
		echo -e "${BOLD}Souhaitez-vous supprimer un autre utilisateur (y/N) :${RESET}"
		read loop
	done
}

function grant_role() {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Attribution de roles${RESET}"
		echo ""
		
		# Input user
		echo -e "${BOLD}Entrez un utilisateur: ${RESET}"
		read role
		echo -e "${BOLD}Entrez un hote: ${RESET}"
		read host
		
		# Attribution des roles
		mysql -e "SHOW GRANTS FOR '${role}'@'${host}';"
		echo -e "${BOLD}Entrez les nouveaux roles pour ${ACCENT}${role}'@'${host}${RESET}${BOLD} (press ENTER to skip): ${RESET}" 
		read priv
		
		if [[ -n "$priv" ]]; then
			mysql -e "GRANT ${priv} TO '${role}'@'${host}';"
			mysql -e "SET DEFAULT ROLE '${priv}' FOR '${role}'@'${host}'"
			mysql -e "SHOW GRANTS FOR '${role}'@'${host}';"
		fi
			
		# loop condition
		echo -e "${BOLD}Souhaitez vous affecter un autre utilisateur (y/N): ${RESET}"
		read loop
	done
}

function grant_priv() {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Attribution de privileges${RESET}"
		echo ""
		
		echo -e "${BOLD}Entrez le type d'utilisateur a affecter (user/role): ${RESET}"
		read entity_type
		
		# Input user
		if [[ $entity_type == "user" ]]; then
			echo -e "${BOLD}Entrez un utilisateur: ${RESET}"
			read role
			echo -e "${BOLD}Entrez un hote: ${RESET}"
			read host
			mysql -e "SHOW GRANTS FOR '${role}'@'${host}';"
			echo -e "${BOLD}Souhaitez vous donner des privileges pour ${ACCENT}'${role}'@'${host}'${RESET}${BOLD} (y/N): ${RESET}"
			read confirm
			echo ""
		elif [[ $entity_type == "role" ]]; then
			echo -e "${BOLD}Entrez un role: ${RESET}"
			read role
			mysql -e "SHOW GRANTS FOR '${role}';"

			echo -e "${BOLD}Souhaitez vous donner des privileges pour ${ACCENT}'${role}'${RESET}${BOLD} (y/N): ${RESET}"
			read confirm
			echo ""
		fi
		
		if [[ "$confirm" == [yY] ]]; then
			loop="y"
			while [[ "$loop" == [Yy] ]]; do
			
				# User inputs
				mysql -e "SHOW DATABASES"
				echo -e "${BOLD}Entrez une database pour ces privileges: ${RESET}"
				read db
				echo ""
				if [[ "$db" != "*" ]]; then
					mysql -e "USE ${db}; SHOW TABLES;"
					echo -e "${BOLD}Entrez une table pour ces privileges: ${RESET}"
					read table
				else
					table="*"
				fi
				echo ""
				echo -e "${BOLD}Entrez les privileges a attribuer: ${RESET}"
				read priv
				echo ""
				
				# GRANTS 
				if [[ $entity_type == "user" ]]; then
					mysql -e "GRANT ${priv} ON ${db}.${table} TO '${role}'@'${host}';"
					mysql -e "SHOW GRANTS FOR '${role}'@'${host}';"
					echo -e "${BOLD}Souhaitez-vous attribuer un autre privilege pour ${ACCENT}'${role}'@'${host}'${RESET}${BOLD} (y/N): ${RESET}"
				elif [[ $entity_type == "role" ]]; then
					mysql -e "GRANT ${priv} ON ${db}.${table} TO '${role}';"
					mysql -e "SHOW GRANTS FOR '${role}';"
					echo -e "${BOLD}Souhaitez-vous attribuer un autre privilege pour ${ACCENT}'${role}'${RESET}${BOLD} (y/N): ${RESET}"
				fi
				
				read loop
			done
		fi
		
		# loop condition
		echo -e "${BOLD}Souhaitez-vous affecter un autre utilisateur (y/N): ${RESET}"
		read loop
	done
}

function revoke_priv() {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Retrait de privileges${RESET}"
		echo ""
		
		echo -e "${BOLD}Entrez le type d'utilisateur a affecter (user/role): ${RESET}"
		read entity_type
		
		# Input user
		if [[ $entity_type == "user" ]]; then
			echo -e "${BOLD}Entrez un utilisateur: ${RESET}"
			read role
			echo -e "${BOLD}Entrez un hote: ${RESET}"
			read host
			
			# Affichache des privileges
			mysql -e "SHOW GRANTS FOR '${role}'@'${host}';"
				
			# Map lines to grants
			mapfile -t grants < <(mysql -e "SHOW GRANTS FOR '${role}'@'${host}';" -B -N)
		elif [[ $entity_type == "role" ]]; then
			echo -e "${BOLD}Entrez un role: ${RESET}"
			read role
			
			# Affichache des privileges
			mysql -e "SHOW GRANTS FOR '${role}';"
				
			# Map lines to grants
			mapfile -t grants < <(mysql -e "SHOW GRANTS FOR '${role}';" -B -N)
		fi

		for grant in "${grants[@]}"; do
			# Replace GRANT by REVOKE
			newitem=${grant/GRANT/REVOKE}
			newitem=${newitem/ TO / FROM }
			echo ""
			echo "${BOLD}Revoke statement: ${ACCENT}${newitem}${RESET}"
			echo -e "${BOLD}Souhaitez vous appliquer ce changement (y/N): ${RESET}"
			read confirm
				
			if [[ $confirm == [yY] ]]; then
				if [[ $entity_type == "user" ]]; then
					mysql -e "$newitem"
					mysql -e "SHOW GRANTS FOR '${role}'@'${host}';"
				elif [[ $entity_type == "role" ]]; then
					mysql -e "$newitem"
					mysql -e "SHOW GRANTS FOR '${role}';"
				fi
			fi
		done

		# loop condition
		echo -e "${BOLD}Souhaitez-vous affecter un autre utilisateur (y/N): ${RESET}"
		read loop
	done
}

function loop_users() {
	mapfile -t fullusers < <(mysql -e "SELECT CONCAT('\'',user,'\'','@','\'',host,'\'') FROM mysql.user WHERE host != '' AND user NOT LIKE '%.sys%' AND user NOT LIKE 'mysql%' AND user != 'root' ORDER BY user;" -B -N)
  	mapfile -t fullroles < <(mysql -e "SELECT user FROM mysql.user WHERE host = '' AND user NOT LIKE '%.sys%' AND user NOT LIKE 'mysql%' AND user != 'root' ORDER BY user;" -B -N)

    printf '%s\n' "${fullusers[@]}"
    printf '%s\n' "${fullroles[@]}"
	echo ""
    if [[ $runas == "require_ssl" ]]; then
		for i in "${fullusers[@]}"; do
			mysql -e "ALTER USER ${i} REQUIRE X509;"
			mysql -e "SHOW GRANTS FOR ${i};" -B
			echo ""
		done
    elif [[ $runas == "authorize_nossl" ]]; then
		for i in "${fullusers[@]}"; do
			mysql -e "ALTER USER ${i} REQUIRE NONE;"
			mysql -e "SHOW GRANTS FOR ${i};"
			echo ""
		done
    fi
}

function require_ssl {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Exiger SSL pour un utilisateur${RESET}"
		echo ""
		
		# Input user
		echo -e "${BOLD}Entrez un utilisateur: ${RESET}"
		read role
		echo -e "${BOLD}Entrez un hote: ${RESET}"
		read host
		mysql -e "ALTER USER '${role}'@'${host}' REQUIRE X509;"
		
		# loop condition
		echo -e "${BOLD}Souhaitez-vous affecter un autre utilisateur (y/N): ${RESET}"
		read loop
	done
}

function authorize_nossl() {
	loop="Y"
	while [[ "$loop" == [Yy] ]]; do
		show_users
		echo -e "${BOLD}Autoriser un utilisateur sans SSL${RESET}"
		echo ""
		
		# Input user
		echo -e "${BOLD}Entrez un utilisateur: ${RESET}"
		read role
		echo -e "${BOLD}Entrez un hote: ${RESET}"
		read host
		mysql -e "ALTER USER '${role}'@'${host}' REQUIRE NONE;"
		
		# loop condition
		echo -e "${BOLD}Souhaitez-vous affecter un autre utilisateur (y/N): ${RESET}"
		read loop
	done
}

#####################################################################
###########  FIN -> Gestion d'utilisateurs et de roles  #############
#####################################################################


# If no automation flags, launch menu, else launch automated script
if [[ -z $switch_database && -z $switch_table && -z $switch_options && -z $switch_cleanup ]]; then

	# Launch menu loop
	while true; do
		clear
		cat << EOF

===========================================================
=======      ${BOLD}Menu de Gestion MariaDB:10.11.15${RESET}      ========
========  Date : $(date "+%a %d %b %Y %I:%M:%S %p %Z")  =========
===========================================================
     
     ${BOLD}Affichage :${RESET}
     1) Afficher les bases de donnees
     2) Afficher les tables pour une base de donnee
     3) Afficher les donnees pour une table
     4) Afficher les scripts de sauvegarde
     5) Afficher les utilisateurs
     6) Afficher les permissions d'un utilisateur

     ${BOLD}Gestion des Sauvegardes et Restaurations :${RESET}
     A) Sauvegarder une base de donnees
     B) Sauvegarder une base de donnees avec chiffrement et compression
     C) Supprimer une base de donnees
     D) Restaurer une base de donnees
     E) Nettoyage des fichiers de sauvegarde

     ${BOLD}Gestion de Privileges et Utilisateurs :${RESET}
     a) Creation d'un nouveau role
     b) Creation d'un nouvel utilisateur
     c) Suppression d'un role existant
     d) Suppression d'un utilisateur existant
     e) Attribution d'un role
     f) Attribution de privileges
     g) Retrait de privileges
     
     h) Exiger SSL pour un utilisateur
     i) Exiger SSL pour tous les utilisateurs
     j) Autoriser un utilisateur sans SSL
     k) Autoriser tous les utilisateurs sans SSL
     
     ${RED}Q) Quitter${RESET}
==========================================================

EOF
		read -p "Selection: " choix

		case $choix in
			1) echo "Afficher les bases de donnees"
			   show_databases
			   ;;
			2) echo "Afficher les tables pour une base de donnee"
			   show_tables
			   ;;
			3) echo "Afficher les donnees pour une table"
			   show_data
			   ;;
			4) echo "Afficher les scripts de sauvegarde"	
			   dryrun="true"
			   cleanup_dumps
			   ;;
			5) echo "Afficher les utilisateurs"
			   show_users
			   read -p "Appuyez sur ENTREE pour continuer"
			   ;;
			6) echo "Afficher les permissions d'un utilisateur"
			   show_grants
			   read -p "Appuyez sur ENTREE pour continuer"
			   ;;			
			A) echo "Sauvegarder une base de donnees"
			   encrypt="N"
			   bckp_soloDB
			   ;;
			B) echo "Sauvegarder une base de donnees avec chiffrement et compression"		   
			   encrypt="Y"
			   bckp_soloDB
			   ;;
			C) echo "Supprimer une base de donnees" 
			   delete_database	   
			   ;;
			D) echo "Restaurer une base de donnees" 	
			   restore_DB	   
			   ;;
			E) echo "Nettoyage des fichiers de sauvegarde"	
			   dryrun="false"
			   cleanup_dumps
			   ;;
			a) echo "Creation d'un nouveau role"
			   create_role
			   ;;
			b) echo "Creation d'un nouvel utilisateur"
			   create_user
			   ;;
			c) echo "Suppression d'un role existant"
			   drop_role
			   ;;
			d) echo "Suppression d'un utilisateur existant"
			   drop_user
			   ;;
			e) echo "Attribution d'un role"
			   grant_role
			   ;;
			f) echo "Attribution de privileges"
			   grant_priv
			   ;;
			g) echo "Retrait de privileges"
			   revoke_priv
			   ;;			   
			h) echo "Exiger SSL pour un utilisateur"
			   require_ssl
			   ;;
			i) echo "Exiger SSL pour tous les utilisateurs"
			   runas="require_ssl"
			   loop_users
			   read -p "Appuyez sur ENTREE pour continuer"
			   ;;			   
			j) echo "Autoriser un utilisateur sans SSL"
			   authorize_nossl
			   ;;
			k) echo "Autoriser tous les utilisateurs sans SSL"
			   runas="authorize_nossl"
			   loop_users
			   read -p "Appuyez sur ENTREE pour continuer"
			   ;;
			[Qq]) echo "Q) Quitter"
			   break;;
		esac
	done
else
	# Automated execution
	if [[ -z $switch_cleanup ]]; then
		encrypt="Y"
		bckp_soloDB
	elif [[ -n $switch_cleanup ]]; then
		dryrun="false"
		cleanup_dumps
	fi
fi
