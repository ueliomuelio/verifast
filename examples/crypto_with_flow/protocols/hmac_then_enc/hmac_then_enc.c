#include "hmac_then_enc.h"

#include <stdlib.h>
#include <string.h>

//@ #include "quantifiers.gh"

#define SERVER_PORT 121212

void sender(char *enc_key, char *hmac_key, char *msg, unsigned int msg_len)
/*@ requires [_]public_invar(hmac_then_enc_pub) &*&
             principal(?sender, _) &*&
             [?f1]cryptogram(enc_key, KEY_SIZE, ?enc_key_cs, ?enc_key_cg) &*&
             [?f2]cryptogram(hmac_key, KEY_SIZE, ?hmac_key_cs, ?hmac_key_cg) &*&
               enc_key_cg == cg_symmetric_key(sender, ?enc_id) &*&
               hmac_key_cg == cg_symmetric_key(sender, ?hmac_id) &*&
                 cg_info(enc_key_cg) == hmac_id &*&
               shared_with(sender, enc_id) == shared_with(sender, hmac_id) &*&
             [?f3]crypto_chars(secret, msg, msg_len, ?msg_cs) &*&
               MAX_SIZE >= msg_len &*& msg_len >= MINIMAL_STRING_SIZE &*&
               col || bad(sender) || bad(shared_with(sender, enc_id)) ?
                 [_]public_generated(hmac_then_enc_pub)(msg_cs)
               :
                 true == send(sender, shared_with(sender, enc_id), msg_cs); @*/
/*@ ensures  principal(sender, _) &*&
             [f1]cryptogram(enc_key, KEY_SIZE, enc_key_cs, enc_key_cg) &*&
             [f2]cryptogram(hmac_key, KEY_SIZE, hmac_key_cs, hmac_key_cg) &*&
             [f3]crypto_chars(secret, msg, msg_len, msg_cs); @*/
{
  int socket;
  havege_state havege_state;

  unsigned int iv_off = 0;
  char iv[16];
  char hmac[64];

  net_usleep(20000);
  if(net_connect(&socket, NULL, SERVER_PORT) != 0)
    abort();
  if(net_set_block(socket) != 0)
    abort();

  {
    aes_context aes_context;
    int enc_len = (int) msg_len + 64;
    char* enc_msg = malloc(enc_len);
    if (enc_msg == 0) abort();

    // Copy message
    //@ chars_split(enc_msg, msg_len);
    memcpy(enc_msg, msg, msg_len);
    //@ assert crypto_chars(secret, enc_msg, msg_len, msg_cs);

    // hmac
    sha512_hmac(hmac_key, KEY_SIZE, msg, msg_len,
                enc_msg + (int) msg_len, 0);
    //@ assert cryptogram(enc_msg + msg_len, 64, ?hmac_cs, ?hmac_cg);
    //@ open cryptogram(enc_msg + msg_len, 64, hmac_cs, hmac_cg);
    //@ crypto_chars_join(enc_msg);
    //@ list<char> enc_msg_cs = append(msg_cs, hmac_cs);
    //@ assert crypto_chars(secret, enc_msg, msg_len + 64, enc_msg_cs);

    int message_len = 16 + enc_len;
    char* message = malloc(message_len);
    if (message == 0) abort();
     
    // IV stuff
    //@ close havege_state(&havege_state);
    havege_init(&havege_state);
    //@ close random_request(sender, 0, false);
    if (havege_random(&havege_state, iv, 16) != 0) abort();
    //@ open cryptogram(iv, 16, ?iv_cs, ?iv_cg);
    //@ close hmac_then_enc_pub(iv_cg);
    //@ leak hmac_then_enc_pub(iv_cg);
    memcpy(message, iv, 16);
    //@ close cryptogram(iv, 16, iv_cs, iv_cg);
    //@ close cryptogram(message, 16, iv_cs, iv_cg);
    //@ public_cryptogram(message, iv_cg);
    havege_free(&havege_state);
    //@ open havege_state(&havege_state);
    //@ assert chars(message, 16, iv_cs);

    // encrypt
    //@ close aes_context(&aes_context);
    if (aes_setkey_enc(&aes_context, enc_key,
                        (unsigned int) (KEY_SIZE * 8)) != 0)
      abort();
    if (aes_crypt_cfb128(&aes_context, AES_ENCRYPT, msg_len + 64,
                         &iv_off, iv, enc_msg, message + 16) != 0)
      abort();
    //@ assert cryptogram(message + 16, msg_len + 64, ?enc_cs, ?enc_cg);
    zeroize(iv, 16);
    aes_free(&aes_context);
    //@ open aes_context(&aes_context);

    //@ close hmac_then_enc_pub(hmac_cg);
    //@ leak hmac_then_enc_pub(hmac_cg);
    //@ take_append(msg_len, msg_cs, hmac_cs);
    //@ drop_append(msg_len, msg_cs, hmac_cs);
    //@ crypto_chars_split(enc_msg, msg_len);
    //@ close cryptogram(enc_msg + msg_len, 64, hmac_cs, hmac_cg);
    //@ public_cryptogram(enc_msg + msg_len, hmac_cg);
    //@ public_chars(enc_msg + msg_len, 64);
    
    /*@ if (col || hmac_then_enc_public_key(sender, enc_id))
        {
          assert [_]public_generated(hmac_then_enc_pub)(msg_cs);
          assert [_]public_generated(hmac_then_enc_pub)(hmac_cs);
          public_crypto_chars(enc_msg, msg_len);
          assert chars(enc_msg, msg_len, msg_cs);
          assert chars(enc_msg + msg_len, 64, hmac_cs);
          chars_join(enc_msg);
          public_chars(enc_msg, msg_len + 64);
          chars_split(enc_msg, msg_len);
          chars_to_secret_crypto_chars(enc_msg, msg_len);
        }
        else
        {
          close hmac_then_enc_pub_1(msg_cs, hmac_cg);
        }
    @*/
    //@ close hmac_then_enc_pub(enc_cg);
    //@ leak hmac_then_enc_pub(enc_cg);
    //@ public_cryptogram(message + 16, enc_cg);
    net_send(&socket, message, (unsigned int) message_len);
    //@ chars_to_secret_crypto_chars(enc_msg + msg_len, 64);
    //@ crypto_chars_join(enc_msg);
    zeroize(enc_msg, enc_len);
    free(enc_msg);
    free(message);
  }
  net_close(socket);
}

int receiver(char *enc_key, char *hmac_key, char *msg)
/*@ requires [_]public_invar(hmac_then_enc_pub) &*&
             principal(?receiver, _) &*&
             [?f1]cryptogram(enc_key, KEY_SIZE, ?enc_key_cs, ?enc_key_cg) &*&
             [?f2]cryptogram(hmac_key, KEY_SIZE, ?hmac_key_cs, ?hmac_key_cg) &*&
               enc_key_cg == cg_symmetric_key(?sender, ?enc_id) &*&
               hmac_key_cg == cg_symmetric_key(sender, ?hmac_id) &*&
                 cg_info(enc_key_cg) == hmac_id &*&
               receiver == shared_with(sender, enc_id) &*&
               receiver == shared_with(sender, hmac_id) &*&
             chars(msg, MAX_SIZE, _); @*/
/*@ ensures  principal(receiver, _) &*&
             [f1]cryptogram(enc_key, KEY_SIZE, enc_key_cs, enc_key_cg) &*&
             [f2]cryptogram(hmac_key, KEY_SIZE, hmac_key_cs, hmac_key_cg) &*&
             chars(msg + result, MAX_SIZE - result, _) &*&
             crypto_chars(?kind, msg, result, ?msg_cs) &*&
             col || bad(sender) || bad(receiver) ||
               (kind == secret && send(sender, receiver, msg_cs)); @*/
{
  int socket1;
  int socket2;

  int size;
  int enc_size;
  char hmac[64];
  unsigned int iv_off = 0;
  char iv[16];
  aes_context aes_context;

  if(net_bind(&socket1, NULL, SERVER_PORT) != 0)
    abort();
  if(net_accept(socket1, &socket2, NULL) != 0)
    abort();
  if(net_set_block(socket2) != 0)
    abort();

  {
    int max_size = 20 + MAX_SIZE + 64;
    char *buffer = malloc (max_size); if (buffer == 0) abort();
    size = net_recv(&socket2, buffer, (unsigned int) max_size);
    if (size <= 16 + 64) abort();
    enc_size = size - 16;
    if (enc_size < MINIMAL_STRING_SIZE || enc_size > MAX_SIZE) abort();
    if (enc_size - 64 < MINIMAL_STRING_SIZE) abort();
    char *buffer_dec = malloc (enc_size); if (buffer_dec == 0) abort();

    // IV stuff
    //@ chars_split(buffer, 16);
    //@ assert chars(buffer, 16, ?iv_cs);
    //@ chars_to_crypto_chars(buffer, 16);
    memcpy(iv, buffer, 16);
    //@ crypto_chars_to_chars(buffer, 16);
    //@ interpret_nonce(iv, 16);
    //@ assert cryptogram(iv, 16, iv_cs, ?iv_cg);

    //Decrypt
    //@ close aes_context(&aes_context);
    if (aes_setkey_enc(&aes_context, enc_key,
                        (unsigned int) (KEY_SIZE * 8)) != 0)
      abort();
    //@ assert chars(buffer + 16, enc_size, ?enc_cs);
    //@ interpret_encrypted(buffer + 16, enc_size);
    //@ assert cryptogram(buffer + 16, enc_size, enc_cs, ?enc_cg);
    //@ assert enc_cg == cg_encrypted(?p2, ?c2, ?dec_cs2, ?iv_cs2);
    if (aes_crypt_cfb128(&aes_context, AES_DECRYPT, (unsigned int) enc_size,
                         &iv_off, iv, buffer + 16, buffer_dec) != 0)
      abort();
    zeroize(iv, 16);
    aes_free(&aes_context);
    //@ open aes_context(&aes_context);
    //@ public_cryptogram_extract(buffer + 16);
    //@ public_cryptogram(buffer + 16, enc_cg);
    
    //@ assert crypto_chars(_, buffer_dec, enc_size, ?dec_cs);
    //@ crypto_chars_split(buffer_dec, enc_size - 64);
    //@ assert crypto_chars(_, buffer_dec, enc_size - 64, ?pay_cs);
    //Verify the hmac
    sha512_hmac(hmac_key, KEY_SIZE, buffer_dec,
                (unsigned int) (enc_size - 64), hmac, 0);
    //@ open exists(?hmac_cg);
    /*@ if (!col && p2 == sender && c2 == enc_id) 
        {
          open cryptogram(hmac, 64, _, hmac_cg);
        }
    @*/
    //@ crypto_chars_distinct(hmac, (void*) buffer_dec + enc_size - 64);
    if (memcmp(hmac, (void*) buffer_dec + enc_size - 64, 64) != 0) abort();
    /*@ if (col || p2 != sender || c2 != enc_id) 
        {
          if (p2 != sender || c2 != enc_id)
          {
            structure s = plaintext_of_incl_one_way_value;
            assert crypto_chars(garbage, buffer_dec + enc_size - 64, 64, ?hmac_cs);
            close exists(hmac_cg);
            close exists(pair(pay_cs, nil));
            close has_structure(dec_cs, s);
            known_garbage_collision(buffer_dec, enc_size, s);
            open  has_structure(dec_cs, s);
            crypto_chars_to_chars(buffer_dec, enc_size);
            assert col == true;
          }
          chars_to_crypto_chars(buffer_dec, enc_size - 64);
          chars_to_crypto_chars(buffer_dec + enc_size - 64, 64);
        }
    @*/
    memcpy(msg, buffer_dec, (unsigned int) enc_size - 64);
    /*@ if (!col && !bad(sender) && !bad(receiver))
        {
          open [_]hmac_then_enc_pub(enc_cg);
          assert [_]hmac_then_enc_pub_1(?msg_cs, ?hmac_cg2);
          assert length(pay_cs) == length(msg_cs);
          drop_append(length(pay_cs), msg_cs, chars_for_cg(hmac_cg2));
          drop_append(length(pay_cs), pay_cs, chars_for_cg(hmac_cg));            
          assert (chars_for_cg(hmac_cg) == chars_for_cg(hmac_cg2));
          assert (chars_for_cg(hmac_cg) == chars_for_cg(hmac_cg2));
          chars_for_cg_inj(hmac_cg, hmac_cg2);
          assert pay_cs == msg_cs;
        }
    @*/
    //@ chars_join(buffer);
    free(buffer);
    //@ crypto_chars_join(buffer_dec);
    zeroize(hmac, 64);
    zeroize(buffer_dec, enc_size);
    free(buffer_dec);
  }
  net_close(socket2);
  net_close(socket1);
  return enc_size - 64;
}

          //close cryptogram(hmac, 64, ?hmac_cs, hmac_cg);
          //public_cryptogram(hmac, hmac_cg);
          
//           assume (false);
//           if (p2 != sender || c2 != enc_id)
//           {
//             assume (false);
//             public_chars(buffer_dec + enc_size - 64, 64, hmac_cs2);
//             close cryptogram(hmac, 64, hmac_cs, hmac_cg);
//             public_cryptogram_extract(hmac);
//             public_cryptogram(hmac, hmac_cg);
//             open [_]hmac_then_enc_pub(hmac_cg);
//           }
