<?php
require('../system.php');
require('crypt.php');

function generateSessionId() {
    srand(time());
    $randNum = rand(1000000000, 2147483647).rand(1000000000, 2147483647).rand(0,9);
    return $randNum;
}

function logExit($text, $output = "Bad login") {
  vtxtlog($text); exit($output);
}

if (empty($_POST)) 

	logExit("[auth16xpost.php] login process [Empty input] [LOGIN PASSWORD clientToken key2");

	loadTool('user.class.php'); 
	BDConnect('auth');

$key2 = $_POST["key"]; $login = decryptStr($_POST["username"], $key2); $password = decryptStr($_POST["password"], $key2); $clientToken = decryptStr($_POST["clientToken"], $key2);

if (!preg_match("/^[a-zA-Z0-9_-]+$/", $password)  or
	!preg_match("/^[a-f0-9-]+$/", $clientToken)) 
		
	logExit("[auth16xpost.php] login process [Bad symbols] User [$login] Password [$password] clientToken [$clientToken]");		

	$BD_Field = (strpos($login, '@') === false)? $bd_users['login'] : $bd_users['email'] ; 	
	$auth_user = new User($login, $BD_Field); 
	
	if ( !$auth_user->id() ) logExit("[auth16xpost.php] login process [Unknown user] User [$login] Password [$password]");
	if ( $auth_user->lvl() <= 1 ) exit("Bad login");
	if ( !$auth_user->authenticate($password) ) logExit("[auth16xpost.php] login process [Wrong password] User [$login] Password [$password]");

    $sessid = generateSessionId();
    BD("UPDATE `{$bd_names['users']}` SET `{$bd_users['session']}`='".TextBase::SQLSafe($sessid)."' WHERE `{$BD_Field}`='".TextBase::SQLSafe($login)."'");
    BD("UPDATE `{$bd_names['users']}` SET `{$bd_users['clientToken']}`='".TextBase::SQLSafe($clientToken)."' WHERE `{$BD_Field}`='".TextBase::SQLSafe($login)."'");

	vtxtlog("[auth16xpost.php] login process [Success] User [$login] Session [$sessid] clientToken[$clientToken]");			
	
        $profile = array ( 'id' => $auth_user->id(), 'name' => $auth_user->name() ) ;
        
        $responce = array(
            'clientToken' => cryptStr($clientToken), 
            'accessToken' => cryptStr($sessid), 
            'availableProfiles' => array ( 0 => $profile), 
            'selectedProfile' => $profile);
        
        exit(json_encode($responce));
?>