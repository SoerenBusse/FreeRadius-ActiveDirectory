# Inner tunnel for the main site
server radius-inner-tunnel {
    listen {
        ipaddr = 127.0.0.1
        port = 18120
        type = auth
    }

    authorize {
        ldap
        inner-eap {
            ok = return
        }
    }

    authenticate {
        inner-eap
        mschap
    }

    post-auth {
      vlan-group-mapping
      
      reject
    }
}
