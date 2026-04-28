<?php if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

return array(
    'name' => 'LimeSurvey',
    'components' => array(
        'db' => array(
          'connectionString' => 'sqlsrv:Server=' . getenv('DB_HOST') . ',' . getenv('DB_PORT') . ';Database=' . getenv('DB_NAME') . ';TrustServerCertificate=True',
          'emulatePrepare' => true,
          'username' => getenv('DB_USER'),
          'password' => getenv('DB_PASSWORD'),
          'charset' => 'utf8',
          'tablePrefix' => '',
          'initSQLs' => array('SET DATEFORMAT ymd;', 'SET QUOTED_IDENTIFIER ON;')),
          'cache' => array(
            'class' => 'CMemCache',
            'useMemcached' => true,
            'servers' => array(array(
                'host' => 'limesurvey-memcached',
                'port' => 11211,
                'weight' => 1)),
          ),
          'log' => array(
            'routes' => array(
              'filerror' => array(
                'class' => 'CFileLogRoute',
                'levels' => 'warning, error',
              ),
            ),
          ),
        'urlManager' => array(
            'urlFormat' => 'get',
            'rules' => require('routes.php'),
            'showScriptName' => true,
        ),
    ),
    'config' => array(
        'baseUrl' => '/limesurvey',
        'debug' => 0,
        'debugsql' => 0,
        'force_ssl' => true,
        'language' => 'en',
        'sitename' => 'BC Gov Survey',
        'updatable' => false,
    )
);
/* End of file config.php */
/* Location: ./application/config/config.php */
