function init() {
    if ! pgrep Docker > /dev/null
    then
        echo "Opening Docker. Please wait..."
        open -a Docker
        sleep 30
    fi

    if [ -d "./vendor" ]
    then
        echo "Deleting vendor directory...\n"
        rm -rf ./vendor
    fi

    if [ -d "./web/core" ]
    then
        echo "Deleting core directory...\n"
        rm -rf ./web/core
    fi

    composer install
    composer update

    # Deleting comments from settings.php
    cat web/sites/default/settings.php | sed "/^#/d" > web/sites/default/settings.php.new && mv web/sites/default/settings.php.new web/sites/default/settings.php
    cat web/sites/default/settings.php | sed "/\*/d" > web/sites/default/settings.php.new && mv web/sites/default/settings.php.new web/sites/default/settings.php
    cat web/sites/default/settings.php | sed "/\/\//d" > web/sites/default/settings.php.new && mv web/sites/default/settings.php.new web/sites/default/settings.php

    if grep -q "'host' => 'localhost'" "./web/sites/default/settings.php"
    then 
        echo "Updating database host in setting.php..."
        cat web/sites/default/settings.php | sed "s/'host' => 'localhost'/'host' => 'mysql'/g" > web/sites/default/settings.php.new && mv web/sites/default/settings.php.new web/sites/default/settings.php
    fi

    project_directory=$(basename $(pwd))
    project_name=$(echo $project_directory | tr '[:upper:]' '[:lower:]')
    
    if [ ! -f "./docker-compose.yml" ]
    then
        echo "Downloading docker-compose.yml..."
        curl -o docker-compose.yml https://raw.githubusercontent.com/callumfairbro/Docker/main/Drupal/docker-compose.yml & pid=$!
        wait $pid

        if grep -q "container_name: drupal" "./docker-compose.yml"
        then 
            echo "Updating drupal container name..."
            cat docker-compose.yml | sed "s/container_name: drupal/container_name: drupal-$project_name/g" > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml
        fi
        if grep -q "container_name: mysql" "./docker-compose.yml"
        then 
            echo "Updating mysql container name..."
            cat docker-compose.yml | sed "s/container_name: mysql/container_name: mysql-$project_name/g" > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml
        fi

        database_line=$(grep "'database' => '" ./web/sites/default/settings.php)
        database=${database_line#*"'database' => '"}
        database=${database%%"'"*}
        cat docker-compose.yml | sed "s/MARIADB_DATABASE:.*/MARIADB_DATABASE: $database/g" > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml
        
        username_line=$(grep "'username' => '" ./web/sites/default/settings.php)
        username=${username_line#*"'username' => '"}
        username=${username%%"'"*}
        cat docker-compose.yml | sed "s/MARIADB_USER:.*/MARIADB_USER: $username/g" > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml

        password_line=$(grep "'password' => '" ./web/sites/default/settings.php)
        password=${password_line#*"'password' => '"}
        password=${password%%"'"*}
        cat docker-compose.yml | sed "s/MARIADB_PASSWORD:.*/MARIADB_PASSWORD: $password/g" > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml

    else 
        echo "docker-compose.yml already exists."
    fi

    if [ ! -f "./Dockerfile" ]
    then
        echo "Downloading Dockerfile..."
        curl -o Dockerfile https://raw.githubusercontent.com/callumfairbro/Docker/main/Drupal/Dockerfile & pid=$!
        wait $pid
    else 
        echo "Dockerfile already exists."
    fi  
}

function up() {

    if ! pgrep Docker > /dev/null
    then
        echo "Opening Docker. Please wait..."
        open -a Docker
        sleep 30
    fi

    docker compose up -d

    cr

}

function import() {

    if [ $# == 1 ]
    then
        database_path="$1"

        if [[ "$database_path" == *".sql" ]]
        then
            project_directory=$(basename $(pwd))
            project_name=$(echo $project_directory | tr '[:upper:]' '[:lower:]')
            mysql_container="mysql-$project_name"
            
            database_line=$(grep "'database' => '" ./web/sites/default/settings.php)
            database=${database_line#*"'database' => '"}
            database=${database%%"'"*}
            
            username_line=$(grep "'username' => '" ./web/sites/default/settings.php)
            username=${username_line#*"'username' => '"}
            username=${username%%"'"*}

            password_line=$(grep "'password' => '" ./web/sites/default/settings.php)
            password=${password_line#*"'password' => '"}
            password=${password%%"'"*}
            
            docker exec -i $mysql_container mysql -u $username -p$password $database < $1

            cr

        else
            echo "The argument must be an sql file."
        fi
        

    else
        echo "This script takes one argument (the path to the database)."        
    fi

}

function down() {

    docker compose down --remove-orphans

}

function cr() {
    # Clearing cache without drush
    if [[ -d web ]]
    then
        echo "Clearing cache..."
        docker compose exec drupal drush cr
        # php ./web/core/lib/Drupal/Core/Cache/Cache.php rebuild
    else
        echo "Please run this command from the root directory."
    fi
}

function uli() {
    # Clearing cache without drush
    if [[ -d web ]]
    then
        docker compose exec drupal drush uli
    else
        echo "Please run this command from the root directory."
    fi
}

"$@"