function up() {

    open -a Docker

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
        curl -u callumfairbro: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 -o docker-compose.yml https://raw.githubusercontent.com/callumfairbro/Docker/main/Drupal/docker-compose.yml
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
        echo $database
        cat docker-compose.yml | sed "s/MARIADB_DATABASE:.*/MARIADB_DATABASE: $database/g" > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml
        
        username_line=$(grep "'username' => '" ./web/sites/default/settings.php)
        username=${username_line#*"'username' => '"}
        username=${username%%"'"*}
        echo $username
        cat docker-compose.yml | sed "s/MARIADB_USER:.*/MARIADB_USER: $username/g" > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml

        password_line=$(grep "'password' => '" ./web/sites/default/settings.php)
        password=${password_line#*"'password' => '"}
        password=${password%%"'"*}
        echo $password
        cat docker-compose.yml | sed "s/MARIADB_PASSWORD:.*/MARIADB_PASSWORD: $password/g" > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml

    else 
        echo "docker-compose.yml already exists."
    fi

    if [ ! -f "./Dockerfile" ]
    then
        echo "Downloading Dockerfile..."
        curl -u callumfairbro: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 -o Dockerfile https://raw.githubusercontent.com/callumfairbro/Docker/main/Drupal/Dockerfile
    else 
        echo "Dockerfile already exists."
    fi  

    docker compose up -d

    cache-rebuild

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

            cache-rebuild

        else
            echo "The argument must be an sql file."
        fi
        

    else
        echo "This script takes one argument (the path to the database)."        
    fi

}

function cache-rebuild() {
    # Clearing cache without drush
    rm -rf web/sites/default/files/php web/sites/default/files/css web/sites/default/files/js web/sites/default/files/imagecache
    rm -rf web/sites/default/files/translations/* web/sites/default/files/php/twig/*
    brew services restart php
}

"$@"