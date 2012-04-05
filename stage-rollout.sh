#!/bin/bash
# This script checks out the repo then does an rsync to the production
# Adjust the server paths to your environment

# REPO TAG
# We use the X.X.X format to name our tag directories
# Ex; For an intial rollout you would enter: 1.0.0
TAG=$1 # <- DO NO SET THIS VALUE

# No TAG? Then ask for one.
if [[ ! $TAG ]];
then
    echo -e "What tag are you updating to?" 
	read TAG
fi

# Repo Info
# Our repositiories include database backups and documentation
# so our code base is located at /src/www/ from the repo root
REPO=http://example.com/REPONAME/tags/$TAG/src/www/
REPO_USER=''
REPO_PASS=''

#Apache Settings
USER=''
USER_GRP=''

#Temps and backups
TEMP=/home/checkouts/svn-tag-$TAG/
BACKUP=/home/backups/site-uploads-$(date +"%F-%H%M%S").tar.gz

# Stage Location
STAGE=/path/to/stage/public/
STAGE_UPLOADS=/path/to/stage/public/img/uploads/
STAGE_CACHE=/path/to/stage/public/cache/


##################################################################################
#	Let's Get it On!
####################

# Utility Functions
die () 
{
	echo $@
	exit 128
}

pause ()
{
	read -p "$*"
}

cleanup ()
{
	rm -rf $TEMP
	echo "Checkout, $TEMP, location has been removed"
	return
}



# Main Logic Functions
setup_loc ()
{
	#Create Checkout Directory
	mkdir -p $TEMP || die "Unable to make directory"

	#Check prod exists and prompt to continue
	if [ -d $PROD ]; then
		echo -e 'Checkout location created and production exists. Do you want to continue with rollout? (yes/no)'
		read answer
		
		if [ "$answer" == 'yes' ]; then
			backup
			rollout
		else
			cleanup
			die 'Rollout canceled by user.'
		fi
	else
		die "Production location doesn't exist"
	fi

}

backup () 
{
	#Backup uploaded assets
	tar --create --verbose -zf $BACKUP $PROD_UPLOADS

	#Backup Database??? Still working on this
	#mysql dump

	if [ $BACKUP ]; then
		pause 'Backup successful. Press [Enter] to continue.'
	else
		echo -e 'Backup failed. Do you want to continue with the rollout? (yes/no)'
		read answer

		if [ "$answer" == 'no' ]; then
			cleanup
			die "Rollout cancelled."
		fi
	fi
	
	return
}

rollout () 
{	
	#Checkout SVN Codebase
	svn checkout $REPO $TEMP --username $REPO_USER --password $REPO_PASS

	#Git Flavor??? Still working this one out
	#git clone git@example.com/repo

	if [ -d $TEMP.svn ]; then
		
		#This is the actually rollout of the codebase
		rsync --archive --verbose --checksum --exclude="*.svn" $TEMP $PROD
		set_permissions
		
		# Should we Cleanup???
		echo -e 'Rollout completed and permissions set. Would you like to cleanup and remove checkout temporary locations? (yes/no)'
		read answer
		if [ $answer == 'yes' ]; then
			cleanup
		else 
			die 'Done! With out cleanup'
		fi
	else
		die 'Checkout failed'
	fi

	return
}

set_permissions () 
{
	#Fix ownership and permissions
	sudo chown -R $USER:$USER_GRP $PROD
	find $PROD -type d -exec chmod 775 {} \;
	find $PROD -type f -exec chmod 664 {} \;
	
	#Caches and uploads writeable
	find $PROD_UPLOADS -type d -exec chmod 777 {} \;
	find $PROD_CACHE -type d -exec chmod 777 {} \;
	find $PROD_CACHE_EE -type d -exec chmod 777 {} \;

	return
}


# Start The Process
setup_loc
